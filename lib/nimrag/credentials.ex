defmodule Nimrag.Credentials do
  require Logger

  alias Nimrag.Client
  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  defstruct username: nil, password: nil, get_mfa: {__MODULE__, :read_user_input_mfa, []}

  def new(username \\ nil, password \\ nil) do
    %__MODULE__{
      username:
        username || get_username() || read_fs_credentials().username ||
          raise("Missing username for authentication"),
      password:
        password || get_password() || read_fs_credentials().password ||
          raise("Missing password for authentication")
    }
  end

  def read_oauth1_token! do
    case read_oauth1_token() do
      {:ok, oauth1_token} -> oauth1_token
      {:error, error} -> raise error
    end
  end

  def read_oauth2_token! do
    case read_oauth2_token() do
      {:ok, oauth2_token} -> oauth2_token
      {:error, error} -> raise error
    end
  end

  def read_oauth1_token do
    read_oauth_token(:oauth1_token, fn data ->
      {:ok, expires_at, 0} = DateTime.from_iso8601(data["expires_at"])

      %OAuth1Token{
        domain: data["domain"],
        expires_at: expires_at,
        mfa_token: data["mfa_token"],
        oauth_token: data["oauth_token"],
        oauth_token_secret: data["oauth_token_secret"]
      }
    end)
  end

  def read_oauth2_token do
    read_oauth_token(:oauth2_token, fn data ->
      {:ok, expires_at, 0} = DateTime.from_iso8601(data["expires_at"])
      {:ok, refresh_token_expires_at, 0} = DateTime.from_iso8601(data["refresh_token_expires_at"])

      %OAuth2Token{
        scope: data["scope"],
        jti: data["jit"],
        token_type: data["token_type"],
        access_token: data["access_token"],
        refresh_token: data["refresh_token"],
        expires_at: expires_at,
        refresh_token_expires_at: refresh_token_expires_at
      }
    end)
  end

  defp read_oauth_token(key, to_struct_mapper) do
    case read_memory_cache(key) do
      nil ->
        case read_fs_oauth_token(key, to_struct_mapper) do
          nil ->
            {:error, "No #{key}.json found."}

          oauth_token ->
            write_memory_cache(key, oauth_token)

            {:ok, oauth_token}
        end

      oauth_token ->
        {:ok, oauth_token}
    end
  end

  defp read_fs_oauth_token(key, to_struct_mapper) do
    token_fs_path = Path.join(config_fs_path(), "#{key}.json")

    with {:ok, data} <- File.read(token_fs_path),
         {:ok, token} <- decode_json(data, "Invalid JSON in #{key}.json") do
      to_struct_mapper.(token)
    else
      _ ->
        nil
    end
  end

  def write_fs_oauth1_token(%Client{oauth1_token: token}), do: write_fs_oauth1_token(token)

  def write_fs_oauth1_token(%OAuth1Token{} = token),
    do: write_fs_oauth_token(:oauth1_token, token)

  def write_fs_oauth2_token(%Client{oauth2_token: token}), do: write_fs_oauth2_token(token)

  def write_fs_oauth2_token(%OAuth2Token{} = token),
    do: write_fs_oauth_token(:oauth2_token, token)

  defp write_fs_oauth_token(key, token) do
    path = Path.join(config_fs_path(), "#{key}.json")

    with {:ok, data} = Jason.encode(token, pretty: true),
         _ <- Logger.debug(fn -> ["writing ", path] end),
         :ok <- File.mkdir_p!(Path.dirname(path)),
         :ok <- File.touch!(path),
         :ok <- File.chmod!(path, 0o600),
         :ok <- File.write!(path, data) do
      :ok
    end
  end

  defp get_username, do: System.get_env("NIMRAG_USERNAME")

  defp get_password do
    cond do
      password = System.get_env("NIMRAG_PASSWORD") ->
        password

      password_file = System.get_env("NIMRAG_PASSWORD_FILE") ->
        password_file
        |> Path.expand()
        |> File.read!()

      password_cmd = System.get_env("NIMRAG_PASSWORD_COMMAND") ->
        [cmd | args] = String.split(password_cmd, " ", trim: true)

        case System.cmd(cmd, args) do
          {output, 0} ->
            output

          _ ->
            raise "Failed to execute password command: cmd=#{cmd} args=#{inspect(args)}"
        end
    end
    |> String.trim()
  end

  def get_mfa(%__MODULE__{get_mfa: {module, fun, args}}) do
    apply(module, fun, args)
  end

  def read_user_input_mfa do
    IO.gets("Enter MFA code: ")
    |> String.trim()
    |> case do
      "" -> {:error, :invalid_mfa}
      code -> {:ok, code}
    end
  end

  defp read_fs_credentials do
    case read_memory_cache(:credentials) do
      nil ->
        credentials_fs_path = Path.join(config_fs_path(), "credentials.json")

        credentials =
          with {:ok, data} <- read_credentials(credentials_fs_path),
               {:ok, credentials} <- decode_json(data, "Invalid JSON in credentials.json") do
            %__MODULE__{
              username: credentials["username"],
              password: credentials["password"]
            }
          else
            _ ->
              %__MODULE__{
                username: nil,
                password: nil
              }
          end

        write_memory_cache(:credentials, credentials)

        credentials

      credentials ->
        credentials
    end
  end

  defp validate_permissions(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} ->
        if mode != 0o100600 do
          raise """
          Invalid permissions for #{path}. Expected 600, got #{Integer.to_string(mode, 8)}
          """
        end

      _ ->
        raise "Could not read permissions for #{path}"
    end
  end

  defp decode_json(data, error_msg) do
    case Jason.decode(data) do
      {:ok, data} ->
        {:ok, data}

      {:error, _} ->
        Logger.warning(error_msg)

        nil
    end
  end

  defp read_credentials(path) do
    if File.exists?(path) do
      validate_permissions(path)
      File.read(path)
    end
  end

  defp config_fs_path do
    Application.get_env(:nimrag, :config_fs_path) || :filename.basedir(:user_config, "nimrag")
  end

  defp read_memory_cache(key) do
    :persistent_term.get({__MODULE__, key}, nil)
  end

  defp write_memory_cache(key, data) do
    :persistent_term.put({__MODULE__, key}, data)
  end
end

defimpl Inspect, for: Nimrag.Credentials do
  alias Nimrag.Credentials
  import Inspect.Algebra

  def inspect(
        %Credentials{username: username},
        opts
      ) do
    details =
      Inspect.List.inspect(
        [
          username:
            (username |> String.split("@", trim: true) |> List.first() |> String.slice(0, 5)) <>
              "...",
          password: "*****"
        ],
        opts
      )

    concat(["#Nimrag.Credentials<", details, ">"])
  end
end
