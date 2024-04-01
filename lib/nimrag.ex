defmodule Nimrag do
  def profile(client) do
    with {:ok, %{body: body, status: 200}} <- Req.get(client.auth_connectapi, url: "/userprofile-service/socialProfile") do
      {:ok, body}
    end
  end
end
