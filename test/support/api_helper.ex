defmodule Nimrag.ApiHelper do
  require Logger

  @doc false
  def store_response_as_test_fixture({:ok, %Req.Response{} = resp, _}) do
    request_path = Req.Response.get_private(resp, :request_path)
    path = rel_fixture_path(request_path)

    File.write!(path, Jason.encode!(resp.body, pretty: true))
    Logger.debug(fn -> "Stored as test fixture: #{Path.relative_to(path, root())}" end)
  end

  def read_response_fixture(conn) do
    path = rel_fixture_path(conn.request_path)

    case File.read(path) do
      {:ok, data} ->
        Jason.decode!(data)

      {:error, reason} ->
        raise """
        Failed to read fixture: #{inspect(reason)}

        Fix it:

        $ touch #{Path.relative_to(path, root())}
        $ nvim #{Path.relative_to(path, root())}

        Then add Garmin's JSON response.

        https://mitmproxy.org/ is an easy way to capture lots raw responses.
        """
    end
  end

  defp rel_fixture_path(request_path) do
    filename = String.replace(request_path, "/", "__") <> ".json"
    Path.join([root(), "test", "fixtures", "api", filename])
  end

  defp root() do
    Path.join([__DIR__, "..", ".."])
  end

  def client() do
    Nimrag.Client.new(req_options: [plug: {Req.Test, Nimrag.Api}])
    |> Nimrag.Client.put_oauth_token(%Nimrag.OAuth1Token{})
    |> Nimrag.Client.put_oauth_token(%Nimrag.OAuth2Token{
      scope: "WRITE",
      jti: "uuid-1234-5678-9012-3456",
      token_type: "Bearer",
      refresh_token: "test-refresh-token",
      access_token: "test-access-token",
      expires_at: DateTime.utc_now() |> DateTime.add(1, :hour),
      refresh_token_expires_at: DateTime.utc_now() |> DateTime.add(1, :hour)
    })
  end
end
