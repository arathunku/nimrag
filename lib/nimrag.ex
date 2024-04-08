defmodule Nimrag do
  alias Nimrag.Api
  alias Nimrag.Client
  import Nimrag.Api, only: [get: 2, response_as_data: 2]

  @type error() :: {:error, any}

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- @moduledoc -->")
             |> Enum.fetch!(1)
  @external_resource "README.md"

  @doc """
  Gets full profile
  """
  @spec profile(Client.t()) :: {:ok, Api.Profile.t(), Client.t()} | error()
  def profile(client), do: client |> profile_req() |> response_as_data(Api.Profile)
  def profile_req(client), do: get(client, url: "/userprofile-service/socialProfile")

  @doc """
  Gets number of completed and goal steps for each day.

  Start date must be equal or before end date.

  Avoid requesting too big ranges as it may fail.
  """
  @spec steps_daily(Client.t()) :: {:ok, list(Api.StepsDaily.t()), Client.t()} | error()
  @spec steps_daily(Client.t(), start_day :: Date.t()) ::
          {:ok, list(Api.StepsDaily.t()), Client.t()} | error()
  @spec steps_daily(Client.t(), start_day :: Date.t(), end_day :: Date.t()) ::
          {:ok, list(Api.StepsDaily.t()), Client.t()} | error()
  def steps_daily(client, start_date \\ Date.utc_today(), end_date \\ Date.utc_today()) do
    if Date.before?(end_date, start_date) do
      {:error,
       {:invalid_date_range, "Start date must be eq or earlier than end date.", start_date,
        end_date}}
    else
      client |> steps_daily_req(start_date, end_date) |> response_as_data(Api.StepsDaily)
    end
  end

  def steps_daily_req(client, start_date \\ Date.utc_today(), end_date \\ Date.utc_today()) do
    get(client,
      url: "/usersummary-service/stats/steps/daily/:start_date/:end_date",
      path_params: [start_date: Date.to_iso8601(start_date), end_date: Date.to_iso8601(end_date)]
    )
  end

  @doc """
  Gets a full summary of a given day.
  """
  @spec user_summary(Client.t()) :: {:ok, list(Api.UserSummaryDaily.t()), Client.t()} | error()
  @spec user_summary(Client.t(), start_day :: Date.t()) ::
          {:ok, Api.UserSummaryDaily.t(), Client.t()} | error()
  def user_summary(client, date \\ Date.utc_today()),
    do: client |> user_summary_req(date) |> response_as_data(Api.UserSummaryDaily)

  def user_summary_req(client, date) do
    get(client,
      url: "/usersummary-service/usersummary/daily",
      params: [calendarDate: Date.to_iso8601(date)]
    )
  end

  @doc """
  Gets latestes activity
  """
  @spec last_activity(Client.t()) :: {:ok, Api.Activity.t(), Client.t()} | any()
  def last_activity(client) do
    case activities(client, 0, 1) do
      {:ok, [], _client} -> {:error, :not_found}
      {:ok, [activity | _], client} -> {:ok, activity, client}
      result -> result
    end
  end

  @doc """
  Gets activities
  """
  @spec activities(Client.t()) :: {:ok, list(Api.Activity.t()), Client.t()} | error()
  @spec activities(Client.t(), offset :: integer()) ::
          {:ok, list(Api.Activity.t()), Client.t()} | error()
  @spec activities(Client.t(), offset :: integer(), limit :: integer()) ::
          {:ok, list(Api.Activity.t()), Client.t()} | error()
  def activities(client, offset \\ 0, limit \\ 10) do
    client |> activities_req(offset, limit) |> response_as_data(Api.Activity)
  end

  def activities_req(client, offset, limit) do
    get(client,
      url: "/activitylist-service/activities/search/activities",
      params: [limit: limit, start: offset]
    )
  end

  @doc """
  Downloads activity.

  Activity download artifact - if original format is used, it's a zip and you
  still need to decode it.

  CSV download is contains a summary of splits.

  ## Working with original zip file

  ```elixir
  {:ok, zip, client} = Nimrag.download_activity(client, 123, :raw)
  {:ok, [file_path]} = :zip.unzip(zip, cwd: "/tmp")
  # Use https://github.com/arathunku/ext_fit to decode FIT file
  {:ok, records} = file_path |> File.read!() |> ExtFit.Decode.decode()
  ```
  """

  @spec download_activity(Client.t(), activity_id :: integer(), :raw) ::
          {:ok, binary(), Client.t()} | error()
  @spec download_activity(Client.t(), activity_id :: integer(), :tcx) ::
          {:ok, binary(), Client.t()} | error()
  @spec download_activity(Client.t(), activity_id :: integer(), :gpx) ::
          {:ok, binary(), Client.t()} | error()
  @spec download_activity(Client.t(), activity_id :: integer(), :kml) ::
          {:ok, binary(), Client.t()} | error()
  @spec download_activity(Client.t(), activity_id :: integer(), :csv) ::
          {:ok, binary(), Client.t()} | error()
  def download_activity(client, activity_id, :raw) do
    with {:ok, %{body: body, status: 200}, client} <-
           download_activity_req(client,
             prefix_url: "download-service/files/activity",
             activity_id: activity_id
           ) do
      {:ok, body, client}
    end
  end

  def download_activity(client, activity_id, format) when format in ~w(tcx gpx kml csv)a do
    with {:ok, %{body: body, status: 200}, client} <-
           download_activity_req(client,
             prefix_url: "download-service/export/#{format}/activity",
             activity_id: activity_id
           ) do
      {:ok, body, client}
    end
  end

  @doc false
  def download_activity_req(client, path_params) do
    get(client,
      url: ":prefix_url/:activity_id",
      path_params: path_params
    )
  end
end
