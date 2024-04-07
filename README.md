# Nimrag

[![Actions Status](https://github.com/arathunku/nimrag/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/arathunku/nimrag/actions/workflows/elixir-build-and-test.yml) 
[![Hex.pm](https://img.shields.io/hexpm/v/nimrag.svg?style=flat)](https://hex.pm/packages/nimrag)
[![Documentation](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=flat)](https://hexdocs.pm/nimrag)
[![License](https://img.shields.io/hexpm/l/nimrag.svg?style=flat)](https://github.com/arathunku/nimrag/blob/main/LICENSE.md)

<!-- @moduledoc -->

Use Garmin API from Elixir. Fetch activities, steps, and more from Garmin Connect.

## Installation

The package can be installed by adding Nimrag to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nimrag, "~> 0.1.0"}
  ]
end
```

or just drop into LiveBook

```elixir
Mix.install([:nimrag])
```

## Usage

### Initial auth

Garmin doesn't have any official public API nor documented official auth.
It means we're required to use username, password and (optionally) MFA code to obtain
authentication tokens. OAuth1 token is valid for up to a year and it's used to generate
OAuth2 token that expires quickly. After OAuth1 token expires, we need to use username,
and password once again. Please see `Nimrag.Auth` docs for more details on various

```elixir
# If you're using it for the first time, we need to get OAuth Tokens first.
{:ok, client} = Nimrag.Client.new()
{:ok, client} = Nimrag.Auth.login_sso()

# OPTIONAL: If you'd like to store OAuth tokens in ~/.config/nimrag and not log in every time
:ok = Nimrag.Credentials.write_fs_oauth1_token(client)
:ok = Nimrag.Credentials.write_fs_oauth2_token(client)
```

### General

Use methods from `Nimrag` to fetch data from Garmin's API.

```
# Restore previously cached in ~/.nimrag OAuth tokens
client = Nimrag.Client.new() |> Nimrag.Client.with_auth(Nimrag.Credentials.read_oauth_tokens!())

# Fetch your profile
{:ok, %Nimrag.Api.Profile{} = profile, client} = Nimrag.profile(client)

# Fetch your latest activity
{:ok, %Nimrag.Api.Activity{} = activity, client} = Nimrag.last_activity(client)

# Call at the end of the session to cache new OAuth2 token
:ok = Nimrag.Credentials.write_fs_oauth2_token(client)
```

### Fallback to raw responses

`Nimrag` module has also methods with `_req` suffix. They return `{:ok, Req.Response{}, client}` and
do not process nor validate returned body. Other methods may return structs with known fields.

This is very important split between response and transformation. Garmin's API may change
at any time but it should still be possible to fallback to raw response if needed, so that
any user of the library didn't have to wait for a hotfix when Garmin  ltimately changes its API.

API calls return {:ok, struct, client} or {:error, error}. Client is there on success
so that it could be chained with always up to date OAuth2 token that will get
automatically updated when it's near expiration

There's at this moment no extensive coverage of API endpoints, feel free to submit
PR with new structs and endpoints, see [Contributing](#contributing).

### Rate limit {: .warning}

By default, Nimrag uses [Hammer](https://github.com/ExHammer/hammer) for rate limiting requests.
If you are already using `Hammer`, you need to ensure `:nimrag` is added as backend.

> #### API note {: .warning}
> Nimrag is not using public Garmin's API so please be good citizens and don't hammer their servers.

See `Nimrag.Client.new/1` for more details about changing the api limits.

## Contributing

Please do! Garmin has a lot of endpoints, some are useful, some are less useful and
responses contain a lot of fields!

You can discover new endpoints by setting up [mitmproxy](https://mitmproxy.org/) and capturing
traffic from mobile app or website. You can also take a look at
[python-garminconnect](https://github.com/cyberjunky/python-garminconnect/blob/master/garminconnect/__init__.py).

For local setup, the project has minimal dependencies and is easy to install 

```sh
# fork and clone the repo
$ mix deps.get
# ensure everything works!
$ mix check
# do your changes
$ mix check
# submit PR!
# THANK YOU!
```

### Adding new API endpoints and responses

1. Add new methods in `Nimrag` module, one with `_req` suffix and one without.
  Method with `_req` should returns direct `Nimrag.Api` result.
1. Call `_req` method in `test` env and save its response as fixture.

    Example for `Nimrag.profile/1`:

    ```elixir
    # MIX_ENV=test iex -S mix
    client = Nimrag.Client.new() |> Nimrag.Client.with_auth(Nimrag.Credentials.read_oauth_tokens!()

    client |> Nimrag.profile_req() |> Nimrag.ApiHelper.store_response_as_test_fixture()
    ```

1. Add tests for new method in [`test/nimrag_test.exs`]
1. Define new [`Schematic`](https://github.com/mhanberg/schematic) schema in `Nimrag.Api`,
  and ensure all tests pass.

## License

Copyright © 2024 Michal Forys

This project is licensed under the MIT license.
