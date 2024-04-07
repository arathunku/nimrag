defmodule Nimrag.Api do
  alias Nimrag.Client
  alias Nimrag.OAuth1Token
  alias Nimrag.Auth

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
    |> req(opts)
    |> Req.get()
    |> case do
      {:ok, %{status: 200} = resp} -> {:ok, resp, Req.Response.get_private(resp, :client)}
      {:error, error} -> {:error, error}
    end
  end

  def response_as_data({:ok, %Req.Response{status: 200, body: body}, client}, struct_module) do
    with {:ok, data} <- response_as_data(body, struct_module) do
      {:ok, data, client}
    end
  end

  def response_as_data({:error, error}, _struct_module), do: {:error, error}

  def response_as_data(body, struct_module) when is_map(body) do
    struct_module.from_api_response(body)
  end

  def response_as_data(body, struct_module) when is_list(body) do
    structs =
      Enum.map(body, fn element ->
        with {:ok, struct} <- struct_module.from_api_response(element) do
          struct
        end
      end)

    first_error =
      Enum.find(structs, fn
        {:error, _} -> true
        _ -> false
      end)

    first_error || {:ok, structs}
  end

  defp req(%Client{} = client, opts) do
    if client.oauth2_token == nil do
      Logger.warning(
        "Setup OAuth2 Token first with Nimrag.Auth.login_sso/2 or NimRag.Client.attach_auth/2"
      )
    end

    client.connectapi
    |> Req.merge(opts)
    |> Req.Request.put_private(:client, client)
    |> Req.Request.append_request_steps(
      req_nimrag_rate_limit: &rate_limit(&1),
      req_nimrag_oauth: &connectapi_auth("connectapi." <> client.domain, &1)
    )
  end

  defp connectapi_auth(host, %{url: %URI{scheme: "https", host: host, port: 443}} = req) do
    client = Req.Request.get_private(req, :client)

    case Auth.maybe_refresh_oauth2_token(client) do
      {:ok, client} ->
        req
        |> Req.Request.put_header("Authorization", "Bearer #{client.oauth2_token.access_token}")
        |> Req.Request.append_response_steps(
          req_nimrag_attach_request_path: fn {req, resp} ->
            %{path: path} = URI.parse(req.url)
            {req, Req.Response.put_private(resp, :request_path, path)}
          end,
          req_nimrag_attach_client: fn {req, resp} ->
            {req, Req.Response.put_private(resp, :client, client)}
          end
        )

      {:error, reason} ->
        {Req.Request.halt(req), {:oauth2_token_refresh_error, reason}}
    end
  end

  defp connectapi_auth(_, req) do
    {Req.Request.halt(req), :invalid_request_host}
  end

  defp rate_limit(req) do
    %Client{oauth1_token: %OAuth1Token{oauth_token: oauth_token}, rate_limit: rate_limit} =
      Req.Request.get_private(req, :client)

    case rate_limit do
      [scale_ms: scale_ms, limit: limit] ->
        case Hammer.check_rate(:nimrag, "garmin.com:#{oauth_token}", scale_ms, limit) do
          {:allow, _count} ->
            req

          {:deny, limit} ->
            {Req.Request.halt(req), {:rate_limit, limit}}
        end

      false ->
        req
    end
  end
end
