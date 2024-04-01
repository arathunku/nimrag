defmodule Nimrag.Credentials do
  require Logger

  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  @derive {Inspect, only: [:username]}
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

  def write_fs_oauth_token(%OAuth1Token{} = token) do
    write_fs_oauth_token(:oauth1_token, token)
  end

  def write_fs_oauth_token(%OAuth2Token{} = token) do
    write_fs_oauth_token(:oauth2_token, token)
  end

  defp write_fs_oauth_token(key, token) do
    path = Path.join(config_fs_path(), "#{key}.json")
    data = Jason.encode!(token, pretty: true)

    Logger.debug(["writing ", path])
    File.mkdir_p!(Path.dirname(path))
    File.touch!(path)
    File.chmod!(path, 0o600)
    File.write!(path, data)

    token
  end

  defp get_username, do: System.get_env("NIMRAG_USERNAME")
  defp get_password, do: System.get_env("NIMRAG_PASSWORD")

  def get_mfa(%__MODULE__{get_mfa: {module, fun, args}}) do
    apply(module, fun, args)
  end

  def read_user_input_mfa do
    code = IO.gets("Enter MFA code: ")
    {:ok, String.trim(code)}
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
