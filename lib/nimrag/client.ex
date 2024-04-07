defmodule Nimrag.Client do
  @type t() :: %__MODULE__{
          connectapi: Req.Request.t(),
          domain: String.t(),
          req_options: Keyword.t(),
          oauth1_token: Nimrag.OAuth1Token.t() | nil,
          oauth2_token: Nimrag.OAuth2Token.t() | nil,
          rate_limit: [scale_ms: integer(), limit: integer()]
        }

  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  defstruct connectapi: nil,
            domain: "garmin.com",
            req_options: [],
            oauth1_token: nil,
            oauth2_token: nil,
            rate_limit: nil

  # Options passed to Hammer, there are no official API limits so let's be
  # good citizens! Page load on Garmin dashboard performs over 200 requests
  @default_rate_limit [scale_ms: 30_000, limit: 60]
  @connectapi_user_agent "Mozilla/5.0 (Android 14; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"

  @moduledoc """
  Struct containing all the required data to interact with the library and to make
  requests to Garmin.

  See `Nimrag.Client.new/1` for more details about the configuration.
  """

  @doc """

  Builds initial struct with the required configuration to interact with Garmin's API.

  Supported options:

  * `:domain` - Garmin's domain, by default it's "garmin.com".
  * `:req_options` - Custom Req options to be passed to all requests.

    You can capture and proxy all requests with [mitmmproxy](https://mitmproxy.org/),

    ```elixir
    req_options: [
      connect_options: [
        protocols: [:http2],
        transport_opts: [cacertfile: Path.expand("~/.mitmproxy/mitmproxy-ca-cert.pem")],
        proxy: {:http, "localhost", 8080, []}
      ]
    ]
    ```


  * `:rate_limit` - Rate limit for all requests, see "Rate limit" in the `Nimrag` module,
    by default it's set to 60 requests every 30 seconds.

    ```elixir
    rate_limit: [scale_ms: 30_000, limit: 10]
    ```

  """

  @spec new() :: t()
  @spec new(Keyword.t()) :: t() | no_return
  def new(config \\ []) when is_list(config) do
    {domain, config} = Keyword.pop(config, :domain, "garmin.com")
    {custom_req_options, config} = Keyword.pop(config, :req_options, [])
    {rate_limit, config} = Keyword.pop(config, :rate_limit, @default_rate_limit)

    if config != [] do
      raise "Unknown config key(s): #{inspect(config)}"
    end

    req_opts = [user_agent: @connectapi_user_agent] |> Keyword.merge(custom_req_options)

    # use: Req.merge
    %__MODULE__{
      req_options: req_opts,
      connectapi:
        [base_url: "https://connectapi.#{domain}"] |> Keyword.merge(req_opts) |> Req.new(),
      domain: domain,
      oauth1_token: nil,
      oauth2_token: nil,
      rate_limit: rate_limit
    }
  end

  @doc """
  Used to attach OAuth tokens to the client

  ## Example

  ```elixir
  Nimrag.Client.new() |> Nimrag.Client.with_auth(Nimrag.Credentials.read_oauth_tokens!())
  ```

  """

  @spec with_auth(t(), {OAuth1Token.t(), OAuth2Token.t()}) :: t()
  def with_auth(%__MODULE__{} = client, {%OAuth1Token{} = oauth1, %OAuth2Token{} = oauth2}) do
    client
    |> put_oauth_token(oauth1)
    |> put_oauth_token(oauth2)
  end

  @doc """
  Adds OAuth1 or OAuth2 token to the client
  """
  @spec put_oauth_token(t(), OAuth1Token.t()) :: t()
  @spec put_oauth_token(t(), OAuth2Token.t()) :: t()
  def put_oauth_token(%__MODULE__{} = client, %OAuth1Token{} = token) do
    client
    |> Map.put(:oauth1_token, token)
  end

  def put_oauth_token(%__MODULE__{} = client, %OAuth2Token{} = token) do
    client
    |> Map.put(:oauth2_token, token)
  end
end

defimpl Inspect, for: Nimrag.Client do
  alias Nimrag.Client
  import Inspect.Algebra

  def inspect(
        %Client{} = client,
        opts
      ) do
    details =
      Inspect.List.inspect(
        [
          domain: client.domain,
          oauth1_token: client.oauth1_token && "#Nimrag.OAuth1Token<...>",
          oauth2_token: client.oauth2_token && "#Nimrag.OAuth2Token<...>"
        ],
        opts
      )

    concat(["#Nimrag.Client<", details, ">"])
  end
end
