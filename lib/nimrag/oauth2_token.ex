defmodule Nimrag.OAuth2Token do
  @type t :: %__MODULE__{
    scope: String.t(),
    jti: String.t(),
    token_type: String.t(),
    refresh_token: String.t(),
    access_token: String.t(),
    expires_at: DateTime.t(),
    refresh_token_expires_at: DateTime.t()
  }
  @derive Jason.Encoder
  defstruct ~w(
      scope jti token_type refresh_token access_token expires_at
      refresh_token_expires_at
    )a

  def expired?(%__MODULE__{expires_at: nil}), do: true

  def expired?(%__MODULE__{expires_at: expires_at}),
    do: DateTime.before?(expires_at, DateTime.utc_now())

  def refresh_token_expired?(%__MODULE__{refresh_token_expires_at: nil}), do: true

  def refresh_token_expired?(%__MODULE__{refresh_token_expires_at: expires_at}),
    do: DateTime.before?(expires_at, DateTime.utc_now())
end

defimpl Inspect, for: Nimrag.OAuth2Token do
  alias Nimrag.OAuth2Token
  import Inspect.Algebra

  def inspect(
        %OAuth2Token{access_token: access_token, refresh_token: refresh_token} = token,
        opts
      ) do
    details =
      Inspect.List.inspect(
        [
          access_token: String.slice(access_token || "", 0, 5) <> "...",
          refresh_token: String.slice(refresh_token || "", 0, 5) <> "...",
          expires_at: token.expires_at,
          expired?: OAuth2Token.expired?(token),
          refresh_token_expires_at: token.refresh_token_expires_at,
          refresh_token_expired?: OAuth2Token.refresh_token_expired?(token)
        ],
        opts
      )

    concat(["#Nimrag.OAuth2Token<", details, ">"])
  end
end
