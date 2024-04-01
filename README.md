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

```elixir
client = Nimrag.Client.new(debug: true)

# OPTIONAL: Read OAuth tokens from disk ~/.config/nimrag
client = Nimrag.Client.attach_auth(client, {
  Nimrag.Credentials.read_oauth1_token!(),
  Nimrag.Credentials.read_oauth2_token!()
})

# required if you don't have OAuth tokens
{:ok, client} = Nimrag.Auth.login_sso(client)

# OPTIONAL: If you'd like to store OAuth tokens in ~/.config/nimrag
Nimrag.Credentials.write_fs_oauth_token(client.oauth1_token)
Nimrag.Credentials.write_fs_oauth_token(client.oauth2_token)

Nimrag.profile(client)
```
