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
  return `{:ok, %Req.Response{}, client}` or `{:error, %Req.Response{}}`.
  """

  @spec get(Client.t(), Keyword.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def get(%Client{} = client, opts) do
    client
    |> req(opts)
    |> Req.get()
    |> case do
      {:ok, %{status: 200} = resp} -> {:ok, resp, Req.Response.get_private(resp, :client)}
      {:error, error} -> {:error, error}
    end
  end

  @spec response_as_data({:ok, Req.Response.t(), Client.t()}, data_module :: atom()) ::
          {:ok, any(), Client.t()} | {:error, Req.Response.t()}
  @spec response_as_data({:error, any()}, data_module :: atom()) :: {:error, any()}
  def response_as_data({:ok, %Req.Response{status: 200, body: body}, client}, data_module) do
    with {:ok, data} <- do_response_as_data(body, data_module) do
      {:ok, data, client}
    end
  end

  def response_as_data({:error, error}, _data_module), do: {:error, error}

  defp do_response_as_data(body, data_module) when is_map(body) do
    data_module.from_api_response(body)
  end

  defp do_response_as_data(body, data_module) when is_list(body) do
    data =
      Enum.map(body, fn element ->
        with {:ok, data} <- data_module.from_api_response(element) do
          data
        end
      end)

    first_error =
      Enum.find(data, fn
        {:error, _} -> true
        _ -> false
      end)

    first_error || {:ok, data}
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
        {Req.Request.halt(req, RuntimeError.exception("oauth2 token refresh error")),
         {:oauth2_token_refresh_error, reason}}
    end
  end

  defp connectapi_auth(_, req) do
    {Req.Request.halt(req, RuntimeError.exception("invalid request host")), :invalid_request_host}
  end

  defp rate_limit(req) do
    %Client{
      oauth1_token: %OAuth1Token{oauth_token: oauth_token},
      rate_limit: rate_limit,
      domain: domain
    } = Req.Request.get_private(req, :client)

    case rate_limit do
      [scale_ms: scale_ms, limit: limit] ->
        case Hammer.check_rate(hammer_backend(), "#{domain}:#{oauth_token}", scale_ms, limit) do
          {:allow, _count} ->
            req

          {:deny, limit} ->
            {Req.Request.halt(req, RuntimeError.exception("rate limit")), {:rate_limit, limit}}
        end

      false ->
        req
    end
  end

  defp hammer_backend do
    # single is a default
    Application.get_env(:nimrag, :hammer, backend: :single)[:backend]
  end
end
