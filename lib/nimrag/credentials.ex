defmodule Nimrag.Credentials do
  require Logger

  alias Nimrag.Client
  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  @type get_mfa() :: nil | mfa() | (-> {:ok, String.t()} | {:error, atom()})

  @type t() :: %__MODULE__{
          username: nil | String.t(),
          password: nil | String.t(),
          get_mfa: get_mfa()
        }
  defstruct username: nil, password: nil, get_mfa: nil

  @moduledoc """
  Holds credentials for authentication. Required only to setup initial OAuth tokens.

  Username and password are needed for `Nimrag.Auth.login_sso/2`.

  > ### Multi factor authentication (MFA) {: .warning}
  > Nimrag supports MFA flow by asking to input code when needed,
  > **it's highly recommended that you set up MFA on you Garmin account**.

  Nimrag tries to provied nice out of box defaults and credentials are obtained in a number of ways:

  * username

      1. Passed as an argument to `new/2`
      1. Environment variable `NIMRAG_USERNAME`
      1. Read from file `{{config_path}}/nimrag/credentials.json`

  * password:

      1. Passerd as an argument to `new/2`
      1. Environment variable `NIMRAG_PASSWORD`
      1. Environment variable `NIMRAG_PASSWORD_FILE` with a path to a file containing the password
      1. Environment variable `NIMRAG_PASSWORD_COMMAND` with a command that will output the password
      1. Read from file `{{config_path}}/credentials.json` (`XDG_CONFIG_HOME`)

  * MFA code - by default it's stdin, but you can provide your own function to read it

  You should use `{{config_path}}/credentials.json` as last resort and in case you do,
  ensure that the file has limited permissions(`600`), otherwise you'll get a warning.

  What's `{{config_path}}`?

  By default, it's going to be `~/.config/nimrag`. You can also supply custom
  value via `config :nimrag, config_fs_path: "/path/to/config"` or `NIMRAG_CONFIG_PATH`.
  This is the location for OAuth tokens, and optionally credentials.

  Created OAuth tokens are stored in `{{config_path}}/oauth1_token.json` and `{{config_path}}/oauth2_token.json`.
  OAuth2 token is valid for around an hour and is automatically refreshed when needed.
  OAuth1Token is valid for up to 1 year and when it expires, you'll need re-authenticate with
  username and password.
  """

  @spec new() :: t()
  @spec new(username :: nil | String.t()) :: t()
  @spec new(username :: nil | String.t(), password :: nil | String.t()) :: t()
  @spec new(username :: nil | String.t(), password :: nil | String.t(), get_mfa :: get_mfa()) ::
          t()
  def new(username \\ nil, password \\ nil, get_mfa \\ nil) do
    %__MODULE__{
      username:
        username || get_username() || read_fs_credentials().username ||
          raise("Missing username for authentication"),
      password:
        password || get_password() || read_fs_credentials().password ||
          raise("Missing password for authentication"),
      get_mfa: get_mfa || {__MODULE__, :read_user_input_mfa, []}
    }
  end

  @doc """
  Reads previously stored OAuth tokens
  """
  @spec read_oauth_tokens! :: {OAuth1Token.t(), OAuth2Token.t()} | no_return
  def read_oauth_tokens! do
    {read_oauth1_token!(), read_oauth2_token!()}
  end

  @doc """
  See `read_oauth1_token/0` for details.
  """
  @spec read_oauth1_token! :: OAuth1Token.t() | no_return
  def read_oauth1_token! do
    case read_oauth1_token() do
      {:ok, oauth1_token} -> oauth1_token
      {:error, error} -> raise error
    end
  end

  @spec read_oauth2_token! :: OAuth2Token.t() | no_return
  def read_oauth2_token! do
    case read_oauth2_token() do
      {:ok, oauth2_token} -> oauth2_token
      {:error, error} -> raise error
    end
  end

  @doc """
  Reads OAuth1 token from `{{config_path}}/oauth1_token.json`

  See `Nimrag.Auth` for more details on how to obtain auth tokens.
  """
  @spec read_oauth1_token :: {:ok, OAuth1Token.t()} | {:error, String.t()}
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

  @doc """
  Reads OAuth2 token from `{{config_path}}/oauth2_token.json`

  See `Nimrag.Auth` for more details on how to obtain auth tokens.
  """
  @spec read_oauth2_token :: {:ok, OAuth2Token.t()} | {:error, String.t()}
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
    case read_fs_oauth_token(key, to_struct_mapper) do
      nil ->
        {:error, "No #{key}.json found."}

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

  @doc """
  Writes currently used OAuth1 token to `{{config_path}}/oauth1_token.json`

  You only need to call this after initial login with `Nimrag.Auth`.
  """
  def write_fs_oauth1_token(%Client{oauth1_token: token}), do: write_fs_oauth1_token(token)

  @doc false
  def write_fs_oauth1_token(%OAuth1Token{} = token),
    do: write_fs_oauth_token(:oauth1_token, token)

  @doc """
  Writes currently used OAuth2 token to `{{config_path}}/oauth2_token.json`

  You should call it after initial login with `Nimrag.Auth`, and each session
  otherwise this token will have to be refreshed very often.
  """
  def write_fs_oauth2_token(%Client{oauth2_token: token}), do: write_fs_oauth2_token(token)

  @doc false
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

  @doc false
  def get_mfa(%__MODULE__{get_mfa: get_mfa}) when is_function(get_mfa), do: get_mfa.()

  def get_mfa(%__MODULE__{get_mfa: {module, fun, args}}) when is_atom(module) and is_atom(fun),
    do: apply(module, fun, args)

  @doc false
  # Reads MFA code from stdin. This is used as a default.

  @spec read_user_input_mfa :: {:ok, String.t()} | {:error, atom()}
  def read_user_input_mfa do
    IO.gets("Enter MFA code: ")
    |> String.trim()
    |> case do
      "" -> {:error, :invalid_mfa}
      code -> {:ok, code}
    end
  end

  defp read_fs_credentials do
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

    credentials
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
    Application.get_env(:nimrag, :config_fs_path) ||
      System.get_env("NIMRAG_CONFIG_PATH") ||
      :filename.basedir(:user_config, "nimrag")
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
