defmodule Nimrag.OAuth1Token do
  @moduledoc """
  See `Nimrag.Credentials` for more details on how to obtain auth tokens.
  """
  @type t() :: %__MODULE__{
          oauth_token: nil | String.t(),
          oauth_token_secret: nil | String.t(),
          mfa_token: nil | String.t(),
          domain: nil | String.t(),
          expires_at: nil | DateTime.t()
        }
  @derive Jason.Encoder
  defstruct ~w(oauth_token oauth_token_secret mfa_token domain expires_at)a

  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: true

  def expired?(%__MODULE__{expires_at: expires_at}),
    do: DateTime.before?(expires_at, DateTime.utc_now())
end

defimpl Inspect, for: Nimrag.OAuth1Token do
  alias Nimrag.OAuth1Token
  import Inspect.Algebra

  def inspect(%OAuth1Token{} = token, opts) do
    fields = [
      oauth_token: redact(token.oauth_token),
      mfa_token: redact(token.mfa_token),
      expired?: OAuth1Token.expired?(token),
      expires_at: token.expires_at
    ]

    container_doc("#Nimrag.OAuth1Token<", fields, ">", opts, &Inspect.List.keyword/2)
  end

  defp redact(value) when is_binary(value), do: String.slice(value, 0, 5) <> "..."
  defp redact(_value), do: "..."
end
