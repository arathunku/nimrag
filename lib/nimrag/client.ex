defmodule Nimrag.Client do
  require Logger

  alias Nimrag.OAuth2Token

  @mobile_user_agent "com.garmin.android.apps.connectmobile"
  @connectapi_user_agent "Mozilla/5.0 (Android 14; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0"

  def new(config \\ []) when is_list(config) do
    {domain, config} = Keyword.pop(config, :domain, "garmin.com")
    {debug, config} = Keyword.pop(config, :debug, false)

    if config != [] do
      raise "Unknown config key(s): #{inspect(config)}"
    end

    default_opts = [
      user_agent: @connectapi_user_agent,
      base_url: "https://connectapi.#{domain}",
      retry: false
    ]

    %{
      sso:
        default_opts
        |> Keyword.put(:base_url, "https://sso.#{domain}")
        |> Keyword.put(:user_agent, @mobile_user_agent)
        |> Keyword.put(:retry, false)
        |> Keyword.put(:redirect, false)
        |> Req.new()
        |> maybe_debug(debug),
      connectapi:
        default_opts
        |> Req.new()
        |> maybe_debug(debug),
      domain: domain,
      mobile_user_agent: @mobile_user_agent
    }
    |> attach_auth()
  end

  def attach_auth(client, {oauth1_token, oauth2_token} \\ {nil, nil}) do
    client
    |> Map.put(:oauth1_token, oauth1_token)
    |> Map.put(:oauth2_token, oauth2_token)
    |> Map.put(
      :auth_connectapi,
      client.connectapi
      |> Req.Request.append_request_steps(
        req_nimrag_oauth: &connectapi_auth(oauth2_token, "connectapi." <> client.domain, &1)
      )
    )
  end

  defp connectapi_auth(nil, _, request) do
    Logger.warning("Setup OAuth2 Token first with Nimrag.Auth.login_sso/2 or NimRag.Client.attach_auth/2")

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

  defp maybe_debug(req, false), do: req

  defp maybe_debug(req, true),
    do:
      Req.Request.append_request_steps(req,
        debug_url: fn request ->
          IO.inspect(request.headers)

          Logger.debug(fn ->
            "#{String.upcase(to_string(request.method))} #{URI.to_string(request.url)}"
          end)

          request
        end
      )
end
