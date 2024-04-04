defmodule Nimrag do
  alias Nimrag.Api

  # TODO: wrap profile in struct
  def profile(client) do
    Api.get(client, url: "/userprofile-service/socialProfile")
  end

  def steps_daily(client, start_date \\ Date.utc_today(), end_date \\ Date.utc_today()) do
    Api.get(client,
      url: "/usersummary-service/stats/steps/daily/:start_date/:end_date",
      path_params: [start_date: Date.to_iso8601(start_date), end_date: Date.to_iso8601(end_date)]
    )
  end
end
