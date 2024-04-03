defmodule Nimrag.Client do
  defstruct connectapi: nil,
            connect: nil,
            domain: "garmin.com",
            req_options: [],
            auth_connectapi: nil,
            auth_connect: nil,
            oauth1_token: nil,
            oauth2_token: nil

  require Logger

  alias Nimrag.OAuth1Token
  alias Nimrag.OAuth2Token

  @connectapi_user_agent "Mozilla/5.0 (Android 14; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"

  def new(config \\ []) when is_list(config) do
    {domain, config} = Keyword.pop(config, :domain, "garmin.com")
    {custom_req_options, config} = Keyword.pop(config, :req_options, [])

    if config != [] do
      raise "Unknown config key(s): #{inspect(config)}"
    end

    req_opts = [user_agent: @connectapi_user_agent] |> Keyword.merge(custom_req_options)

    # use: Req.merge
    %__MODULE__{
      req_options: req_opts,
      connectapi:
        [base_url: "https://connectapi.#{domain}"] |> Keyword.merge(req_opts) |> Req.new(),
      connect: [base_url: "https://connect.#{domain}"] |> Keyword.merge(req_opts) |> Req.new(),
      domain: domain,
      oauth1_token: nil,
      oauth2_token: nil
    }
    |> attach_req_auth()
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
    |> attach_req_auth()
  end

  defp attach_req_auth(%__MODULE__{} = client) do
    client
    |> Map.put(
      :auth_connectapi,
      client.connectapi
      |> Req.Request.append_request_steps(
        req_nimrag_oauth: &connectapi_auth(client.oauth2_token, "connectapi." <> client.domain, &1)
      )
    )
    |> Map.put(
      :auth_connect,
      client.connect
      |> Req.Request.append_request_steps(
        req_nimrag_oauth: &connectapi_auth(client.oauth2_token, "connect." <> client.domain, &1)
      )
    )
  end

  defp connectapi_auth(nil, _, request) do
    Logger.warning(
      "Setup OAuth2 Token first with Nimrag.Auth.login_sso/2 or NimRag.Client.attach_auth/2"
    )

    {Req.Request.halt(request), :oauth2_missing}
  end

  defp connectapi_auth(
         oauth2_token,
         host,
         %{url: %URI{scheme: "https", host: host, port: 443}} = request
       ) do
    if OAuth2Token.expired?(oauth2_token) do
      {Req.Request.halt(request), :oauth2_token_expired}
    else
      Req.Request.put_header(request, "Authorization", "Bearer #{oauth2_token.access_token}")
    end
  end

  defp connectapi_auth(_, _, request) do
    {Req.Request.halt(request), :invalid_request}
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
          oauth1_token: client.oauth1_token,
          oauth2_token: client.oauth2_token
        ],
        opts
      )

    concat(["#Nimrag.Client<", details, ">"])
  end
end
