defmodule Nimrag.OAuthTokenInspectTest do
  use ExUnit.Case, async: true

  alias Nimrag.{Credentials, OAuth1Token, OAuth2Token}

  describe "inspect/1" do
    test "redacts OAuth2 access and refresh tokens" do
      token = %OAuth2Token{
        access_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature",
        refresh_token: "eyJyZWZyZXNoVG9rZW5WYWx1ZSI6ImFiYzEyMyJ9",
        expires_at: ~U[2026-08-17 07:42:12Z],
        refresh_token_expires_at: ~U[2026-09-15 08:48:18Z]
      }

      inspected = inspect(token)

      assert inspected =~ "#Nimrag.OAuth2Token<"
      assert inspected =~ "eyJhb..."
      refute inspected =~ "payload.signature"
      refute inspected =~ "ImFiYzEyMyJ9"
      refute inspected =~ "#Inspect.Error"
    end

    test "redacts OAuth1 tokens and hides the secret" do
      token = %OAuth1Token{
        oauth_token: "89c6fb1f-d5d1-407d-bef0-2dd9fdb7cc0b",
        oauth_token_secret: "super-secret-token-value",
        mfa_token: "MFA-10990-secret",
        expires_at: ~U[2027-08-16 08:48:24Z]
      }

      inspected = inspect(token)

      assert inspected =~ "#Nimrag.OAuth1Token<"
      assert inspected =~ "89c6f..."
      refute inspected =~ "super-secret-token-value"
      refute inspected =~ "MFA-10990-secret"
      refute inspected =~ "#Inspect.Error"
    end

    test "redacts credentials username and password" do
      credentials = %Credentials{username: "athlete@example.com", password: "hunter2"}
      inspected = inspect(credentials)

      assert inspected =~ "#Nimrag.Credentials<"
      assert inspected =~ "athle..."
      refute inspected =~ "athlete@example.com"
      refute inspected =~ "hunter2"
      refute inspected =~ "#Inspect.Error"
    end
  end
end
