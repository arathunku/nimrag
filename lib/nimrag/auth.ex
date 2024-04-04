defmodule Nimrag.Auth do
  alias Nimrag.Client
  alias Nimrag.Credentials
  alias Nimrag.{OAuth1Token, OAuth2Token}

  require Logger

  # hardcoded values from fetched s3 url in https://github.com/matin/garth
  # base64 encoded values, based on GitHub issues, that's what the app is using
  @oauth_consumer_key Base.url_decode64!("ZmMzZTk5ZDItMTE4Yy00NGI4LThhZTMtMDMzNzBkZGUyNGMw")
  @oauth_consumer_secret Base.url_decode64!("RTA4V0FSODk3V0V5MmtubjdhRkJydmVnVkFmMEFGZFdCQkY=")
  @mobile_user_agent "com.garmin.android.apps.connectmobile"

  # simulate web-like login flow without using secret key/secret extracted from mobile app
  # def login_web(client) do
  # end

  def login_sso, do: login_sso(Client.new(), Credentials.new())
  def login_sso(%Credentials{} = credentials), do: login_sso(Client.new(), credentials)
  def login_sso(%Client{} = client), do: login_sso(client, Credentials.new())

  def login_sso(%Client{} = client, %Credentials{} = credentials) do
    with {:ok, sso} <- build_sso(client),
         {:ok, embed_response} <- embed_req(sso),
         {:ok, signin_response} <- signin_req(sso, embed_response),
         {:ok, signin_post_response} <-
           submit_signin_req(sso, signin_response, credentials),
         cookie = get_cookie(signin_response),
         {:ok, signin_post_response} <-
           maybe_handle_mfa(sso, signin_post_response, cookie, credentials),
         {:ok, ticket} <- get_ticket(signin_post_response),
         {:ok, oauth1_token} <- get_oauth1_token(client, ticket),
         {:ok, oauth2_token} <- get_oauth2_token(client, oauth1_token) do
      {:ok,
       client
       |> Client.put_oauth_token(oauth1_token)
       |> Client.put_oauth_token(oauth2_token)}
    else
      error ->
        Logger.debug(fn ->
          "Details why login failed: #{inspect(error)}. It may contain sensitive data, depending on the error."
        end)

        {:error, "Couldn't fully authenticate. Error data is only printed on debug log level."}
    end
  end

  def get_oauth1_token(%Client{} = client, ticket) do
    url = "/oauth-service/oauth/preauthorized"

    params = [
      {"ticket", ticket},
      {"login-url", sso_url(client) <> "/embed"},
      {"accepts-mfa-tokens", "true"}
    ]

    {{"Authorization", oauth}, req_params} =
      OAuther.sign("get", client.connectapi.options.base_url <> url, params, oauth_creds())
      |> OAuther.header()

    now = DateTime.utc_now()

    {:ok, response} =
      client.connectapi
      |> Req.Request.put_header("Authorization", oauth)
      |> Req.get(
        url: url,
        params: req_params,
        user_agent: @mobile_user_agent
      )

    %{"oauth_token" => token, "oauth_token_secret" => secret} =
      query = URI.decode_query(response.body)

    {:ok,
     %OAuth1Token{
       oauth_token: token,
       oauth_token_secret: secret,
       domain: client.domain,
       mfa_token: query["mfa_token"] || "",
       # TODO: OAuth1Token, Is that 365 days true with MFA active? We'll wait and see!
       expires_at: DateTime.add(now, 365, :day)
     }}
  end

  def refresh_oauth2_token(%Client{} = client, opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if client.oauth2_token == nil || OAuth2Token.expired?(client.oauth2_token) || force do
      with {:ok, oauth2_token} <- get_oauth2_token(client, client.oauth1_token) do
        {:ok, client |> Client.put_oauth_token(oauth2_token)}
      end
    else
      {:ok, client}
    end
  end

  def get_oauth2_token(%Client{} = client) do
    get_oauth2_token(client, client.oauth1_token)
  end

  def get_oauth2_token(%Client{} = client, %OAuth1Token{} = oauth1_token) do
    url = "/oauth-service/oauth/exchange/user/2.0"

    params =
      if oauth1_token.mfa_token && oauth1_token.mfa_token != "" do
        [{"mfa_token", oauth1_token.mfa_token}]
      else
        []
      end

    {{"Authorization" = auth, oauth}, req_params} =
      OAuther.sign(
        "post",
        client.connectapi.options.base_url <> url,
        params,
        oauth_creds(oauth1_token)
      )
      |> OAuther.header()

    now = DateTime.utc_now()

    {:ok, response} =
      client.connectapi
      |> Req.Request.put_header(auth, oauth)
      |> Req.post(
        url: url,
        form: req_params,
        user_agent: @mobile_user_agent
      )

    %{
      "access_token" => access_token,
      "expires_in" => expires_in,
      "jti" => jti,
      "refresh_token" => refresh_token,
      "refresh_token_expires_in" => refresh_token_expires_in,
      "scope" => scope,
      "token_type" => token_type
    } = response.body

    expires_at = DateTime.add(now, expires_in, :second)
    refresh_token_expires_at = DateTime.add(now, refresh_token_expires_in, :second)

    {:ok,
     %OAuth2Token{
       access_token: access_token,
       jti: jti,
       expires_at: expires_at,
       refresh_token: refresh_token,
       refresh_token_expires_at: refresh_token_expires_at,
       scope: scope,
       token_type: token_type
     }}
  end

  defp maybe_handle_mfa(sso, %Req.Response{} = prev_resp, cookie, credentials) do
    if String.contains?(get_location(prev_resp), "verifyMFA") do
      submit_mfa(sso, cookie, credentials)
    else
      {:ok, prev_resp}
    end
  end

  defp submit_mfa(sso, cookie, credentials) do
    with {:ok, response} <- get_mfa(sso, cookie),
         {:ok, csrf_token} <- get_csrf_token(response),
         {:ok, mfa_code} = Credentials.get_mfa(credentials),
         {:ok, %{status: 302} = response} <- submit_mfa_req(sso, csrf_token, cookie, mfa_code) do
      uri = response |> get_location() |> URI.parse()

      sso.client
      |> Req.Request.put_header("cookie", Enum.uniq(cookie ++ get_cookie(response)))
      |> Req.Request.put_header(
        "referer",
        "#{sso.url}/verifyMFA/loginEnterMfaCode"
      )
      |> Req.get(
        url: "/login",
        params: URI.decode_query(uri.query)
      )
      |> check_response(:submit_mfa)
    end
  end

  defp oauth_creds do
    OAuther.credentials(
      consumer_key: @oauth_consumer_key,
      consumer_secret: @oauth_consumer_secret
    )
  end

  defp oauth_creds(%OAuth1Token{oauth_token: token, oauth_token_secret: secret}) do
    OAuther.credentials(
      consumer_key: @oauth_consumer_key,
      consumer_secret: @oauth_consumer_secret,
      token: token,
      token_secret: secret
    )
  end

  defp get_cookie(%Req.Response{} = response),
    do: Req.Response.get_header(response, "set-cookie")

  defp get_location(%Req.Response{} = response),
    do: List.first(Req.Response.get_header(response, "location")) || ""

  defp get_csrf_token(%Req.Response{body: body, status: 200}) do
    case Regex.scan(~r/name="_csrf"\s+value="(.+?)"/, body) do
      [[_, csrf_token]] -> {:ok, csrf_token}
      _ -> {:error, :missing_csrf}
    end
  end

  defp get_ticket(%Req.Response{body: body, status: 200}) do
    case Regex.scan(~r/embed\?ticket=([^"]+)"/, body) do
      [[_, ticket]] -> {:ok, ticket}
      _ -> {:error, :missing_ticket}
    end
  end

  defp submit_mfa_req(sso, csrf_token, cookie, mfa_code) do
    sso.client
    |> Req.Request.put_header("cookie", cookie)
    |> Req.Request.put_header("referer", "#{sso.url}/verifyMFA")
    |> Req.post(
      url: "/verifyMFA/loginEnterMfaCode",
      params: sso.signin_params,
      form: %{
        "mfa-code" => mfa_code,
        fromPage: "setupEnterMfaCode",
        embed: "true",
        _csrf: csrf_token
      }
    )
    |> check_response(:signin_req)
  end

  defp get_mfa(sso, cookie) do
    sso.client
    |> Req.Request.put_header("cookie", cookie)
    |> Req.Request.put_header("referer", "#{sso.url}/signin")
    |> Req.get(
      url: "/verifyMFA/loginEnterMfaCode",
      params: sso.signin_params
    )
    |> check_response(:get_mfa)
  end

  defp embed_req(sso) do
    Req.get(sso.client, url: "/embed", params: sso.embed_params)
    |> check_response(:embed_req)
  end

  defp signin_req(sso, %Req.Response{} = prev_resp) do
    sso.client
    |> Req.Request.put_header("cookie", get_cookie(prev_resp))
    |> Req.Request.put_header("referer", "#{sso.url}/embed")
    |> Req.get(
      url: "/signin",
      params: sso.signin_params
    )
    |> check_response(:signin_req)
  end

  defp submit_signin_req(sso, %Req.Response{} = prev_resp, credentials) do
    with {:ok, csrf_token} <- get_csrf_token(prev_resp) do
      sso.client
      |> Req.Request.put_header("cookie", get_cookie(prev_resp))
      |> Req.Request.put_header("referer", "#{sso.url}/signin")
      |> Req.post(
        url: "/signin",
        params: sso.signin_params,
        form: %{
          username: credentials.username,
          password: credentials.password,
          embed: "true",
          _csrf: csrf_token
        }
      )
      |> check_response(:submit_signin_req)
    end
  end

  def build_sso(%Client{} = client) do
    sso_url = sso_url(client)
    sso_embed = "#{sso_url}/embed"

    embed_params = %{
      id: "gauth-widget",
      embedWidget: "true",
      gauthHost: sso_url
    }

    signin_params =
      Map.merge(embed_params, %{
        gauthHost: sso_embed,
        service: sso_embed,
        source: sso_embed,
        redirectAfterAccountLoginUrl: sso_embed,
        redirectAfterAccountCreationUrl: sso_embed
      })

    {:ok,
     %{
       client: sso_client(client),
       url: sso_url,
       embed: sso_embed,
       embed_params: embed_params,
       signin_params: signin_params
     }}
  end

  defp sso_client(%Client{} = client) do
    client.req_options
    |> Keyword.put(:base_url, sso_url(client))
    |> Keyword.put(:user_agent, @mobile_user_agent)
    |> Keyword.put(:retry, false)
    |> Keyword.put(:redirect, false)
    |> Req.new()
  end

  defp sso_url(%{domain: domain}) do
    "https://sso.#{domain}/sso"
  end

  defp check_response({:ok, %{status: status} = response}, _tag) when status in [200, 302],
    do: {:ok, response}

  defp check_response({:ok, response}, tag), do: {:error, {tag, response}}
  defp check_response({:error, err}, tag), do: {:error, {tag, err}}
end
