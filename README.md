# Nimrag

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nimrag` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nimrag, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nimrag>.

## Usage

```elixir
# If you're using it for the first time
{:ok, client} = Nimrag.Auth.login_sso()

# OPTIONAL: If you'd like to store OAuth tokens in ~/.config/nimrag
:ok = Nimrag.Credentials.write_fs_oauth1_token(client)
:ok = Nimrag.Credentials.write_fs_oauth2_token(client)

# Restore previously cached OAuth tokens
client = Nimrag.Client.new() |> Nimrag.Client.with_auth(Nimrag.Credentials.read_oauth_tokens!())

Nimrag.profile(client)

# Refresh OAuth2 token, it's valid for only some time.
# OAuth1 token is valid for up to 1 year. After that username/password is required again.
# TODO: get and return client
{:ok, client} = Nimrag.Auth.refresh_oauth2_token(client)
:ok = Nimrag.Credentials.write_fs_oauth2_token(client)
```
