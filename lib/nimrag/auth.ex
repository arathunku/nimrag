defmodule Nimrag.Auth do
  alias Nimrag.Auth
  alias Nimrag.Client
  alias Nimrag.Credentials
  alias Nimrag.{OAuth1Token, OAuth2Token}

  # hardcoded values from fetched s3 url in https://github.com/matin/garth
  # base64 encoded values, based on GitHub issues, that's what the app is using
  @oauth_consumer_key Base.url_decode64!("ZmMzZTk5ZDItMTE4Yy00NGI4LThhZTMtMDMzNzBkZGUyNGMw")
  @oauth_consumer_secret Base.url_decode64!("RTA4V0FSODk3V0V5MmtubjdhRkJydmVnVkFmMEFGZFdCQkY=")

  # simulate web-like login flow without using secret key/secret extracted from mobile app
  # def login_web(client) do
  # end

  def login_sso(client, %Credentials{} = credentials) do
    sso = client.sso.options.base_url <> "/sso"
    sso_embed = "#{sso}/embed"

    sso_embed_params = %{
      id: "gauth-widget",
      embedWidget: "true",
      gauthHost: sso
    }

    signin_params =
      Map.merge(sso_embed_params, %{
        gauthHost: sso_embed,
        service: sso_embed,
        source: sso_embed,
        redirectAfterAccountLoginUrl: sso_embed,
        redirectAfterAccountCreationUrl: sso_embed
      })

    {:ok, embed_response} = Req.get(client.sso, url: "/sso/embed", params: sso_embed_params)

    cookie = Req.Response.get_header(embed_response, "set-cookie")

    {:ok, signin_response} =
      client.sso
      |> Req.Request.put_header("cookie", cookie)
      |> Req.Request.put_header("referer", sso_embed)
      |> Req.get(
        url: "/sso/signin",
        params: signin_params
      )

    cookie = Req.Response.get_header(signin_response, "set-cookie")
    [[_, csrf_token]] = Regex.scan(~r/name="_csrf"\s+value="(.+?)"/, signin_response.body)

    {:ok, signin_post_response} =
      client.sso
      |> Req.Request.put_header("cookie", cookie)
      |> Req.Request.put_header("referer", "#{sso}/signin")
      |> Req.post(
        url: "/sso/signin",
        params: signin_params,
        form: %{
          username: credentials.username,
          password: credentials.password,
          embed: "true",
          _csrf: csrf_token
        }
      )

    [[_, title]] = Regex.scan(~r/<title>(.+?)<\/title>/, signin_post_response.body)
    [location] = Req.Response.get_header(signin_post_response, "location")
    cookie = Req.Response.get_header(signin_post_response, "set-cookie")

    {:ok, response_with_ticket} =
      cond do
        String.contains?(location, "verifyMFA") ->
          {:ok, mfa_code} = Credentials.get_mfa(credentials)

          {:ok, response} =
            submit_mfa(client, location, signin_params, mfa_code, csrf_token, cookie)

          [[_, title]] = Regex.scan(~r/<title>(.+?)<\/title>/, response.body)

          if title == "Success" do
            {:ok, response}
          else
            {:error, "Invalid title=#{title}"}
          end

        title == "Success" ->
          {:ok, signin_post_response}

        true ->
          {:error, "Invalid title=#{title}"}
      end

    [[_, ticket]] = Regex.scan(~r/embed\?ticket=([^"]+)"/, response_with_ticket.body)

    {:ok, oauth1_token} = get_oauth1_token(client, ticket)
    {:ok, oauth2_token} = get_oauth2_token(client, oauth1_token)

    {:ok, Client.attach_auth(client, {oauth1_token, oauth2_token})}
  end

  def get_oauth1_token(client, ticket) do
    url = "/oauth-service/oauth/preauthorized"

    params = [
      {"ticket", ticket},
      {"login-url", client.sso.options.base_url <> "/sso/embed"},
      {"accepts-mfa-tokens", "true"}
    ]

    oauth_params =
      OAuther.sign("get", client.connectapi.options.base_url <> url, params, Auth.creds())

    {{"Authorization", oauth}, req_params} = OAuther.header(oauth_params)

    now = DateTime.utc_now()

    {:ok, response} =
      client.connectapi
      |> Req.Request.put_header("Authorization", oauth)
      |> Req.get(
        url: url,
        params: req_params,
        user_agent: client.mobile_user_agent
      )

    %{"oauth_token" => token, "oauth_token_secret" => secret} =
      query = URI.decode_query(response.body)

    %OAuth1Token{
      oauth_token: token,
      oauth_token_secret: secret,
      domain: client.domain,
      mfa_token: query["mfa_token"] || "",
      # TODO: OAuth1Token, Is that true with MFA active?
      expires_at: DateTime.add(now, 365, :day)
    }
  end

  def get_oauth2_token(client) do
    get_oauth2_token(client, client.get_oauth1_token)
  end

  def get_oauth2_token(client, oauth1_token) do
    url = "/oauth-service/oauth/exchange/user/2.0"

    oauth_params =
      OAuther.sign(
        "post",
        client.connectapi.options.base_url <> url,
        [],
        Auth.creds(oauth1_token)
      )

    {{"Authorization", oauth}, _req_params} = OAuther.header(oauth_params)

    now = DateTime.utc_now()

    {:ok, response} =
      client.connectapi
      |> Req.Request.put_header("Authorization", oauth)
      |> Req.post(
        url: url,
        form:
          if oauth1_token.mfa_token && oauth1_token.mfa_token != "" do
            %{
              mfa_token: oauth1_token.mfa_token
            }
          else
            %{}
          end,
        user_agent: client.mobile_user_agent
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

  defp submit_mfa(client, location, signin_params, mfa_code, csrf_token, cookie) do
    client.sso
    |> Req.Request.put_header("cookie", cookie)
    |> Req.Request.put_header("referer", location)
    |> Req.post(
      url: "/sso/verifyMFA/loginEnterMfaCode",
      params: signin_params,
      redirect: true,
      form: %{
        "mfa-code" => mfa_code,
        fromPage: "setupEnterMfaCode",
        embed: "true",
        _csrf: csrf_token
      }
    )
  end

  def creds do
    OAuther.credentials(
      consumer_key: @oauth_consumer_key,
      consumer_secret: @oauth_consumer_secret
    )
  end

  def creds(%OAuth1Token{oauth_token: token, oauth_token_secret: secret}) do
    OAuther.credentials(
      consumer_key: @oauth_consumer_key,
      consumer_secret: @oauth_consumer_secret,
      token: token,
      token_secret: secret
    )
  end
end
