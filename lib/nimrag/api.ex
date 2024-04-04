defmodule Nimrag.Api do
  alias Nimrag.Client
  alias Nimrag.OAuth2Token

  require Logger

  @moduledoc """
  Module to interact with Garmin's API **after** authentication.

  It handles common patterns of making the requests, pagination, list, etc.

  By default first argument is always the client, second options to Req, and
  all requests are executed against "connectapi" subdomain unless specified otherwise.

  OAuth2 token may get refreshed automatically if expired. This is why all responses
  return {:ok, %Req.Response{}, client} or {:error, %Req.Response{}, client}.
  """

  def get(%Client{} = client, opts) do
    client
    |> req()
    |> Req.get(opts)
    |> case do
      {:ok, %{status: 200} = resp} -> {:ok, resp, client}
      {:error, response} -> {:error, response, client}
    end
  end

  def get(%Client{} = client, opts) do
    client
    |> req()
    |> Req.get(opts)
    |> case do
      {:ok, %{status: 200} = resp} -> {:ok, resp, client}
      {:error, response} -> {:error, response, client}
    end
  end

  defp req(%Client{} = client) do
    client.connectapi
    |> Req.Request.append_request_steps(
      req_nimrag_oauth: &connectapi_auth(client.oauth2_token, "connectapi." <> client.domain, &1)
    )
  end

  defp connectapi_auth(nil, _, request) do
    Logger.warning(
      "Setup OAuth2 Token first with Nimrag.Auth.login_sso/2 or NimRag.Client.attach_auth/2"
    )

    {Req.Request.halt(request), :oauth2_missing}
  end

  # TODO: trigger maybe_refresh
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
