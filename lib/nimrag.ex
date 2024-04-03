defmodule Nimrag do
  def profile(client) do
    with {:ok, %{body: body, status: 200}} <-
           Req.get(client.auth_connectapi, url: "/userprofile-service/socialProfile") do
      {:ok, body}
    end
  end

  def steps_daily(client, date \\ Date.utc_today()) do
    with {:ok, %{body: body, status: 200}} <-
           Req.get(client.auth_connect,
             url: "/usersummary-service/stats/steps/daily/2024-03-28/2024-04-03"
           ) do
      {:ok, body}
    end
  end
end
