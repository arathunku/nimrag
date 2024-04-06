defmodule Nimrag.Client do
  @type t :: %__MODULE__{
    connectapi: Req.t(),
    domain: String.t(),
    req_options: Keyword.t(),
    oauth1_token: OAuth1Token.t() | nil,
    oauth2_token: OAuth2Token.t() | nil,
    rate_limit: [scale_ms: integer(), limit: integer()]
  }

  defstruct connectapi: nil,
            domain: "garmin.com",
            req_options: [],
            oauth1_token: nil,
            oauth2_token: nil,
            rate_limit: nil

  # Options passed to Hammer, there are no official API limits so let's be
  # good citizens! Page load on Garmin dashboard performs over 200 requests
  # @default_rate_limit rate_limit: [scale_ms: 30_000, limit: 60]
  @default_rate_limit [scale_ms: 30_000, limit: 2]

  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  @connectapi_user_agent "Mozilla/5.0 (Android 14; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"

  @doc """

  Adding proxy to all requests

  client = Nimrag.Client.new(
    req_options: [
      connect_options: [
        transport_opts: [cacertfile: Path.expand("~/.mitmproxy/mitmproxy-ca-cert.pem")],
        proxy: {:http, "localhost", 8080, []}
      ]
    ]
  )
  """
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

  def with_auth(%__MODULE__{} = client, {oauth1_token, oauth2_token}) do
    client
    |> put_oauth_token(oauth1_token)
    |> put_oauth_token(oauth2_token)
  end

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
