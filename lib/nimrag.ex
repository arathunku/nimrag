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
  @spec steps_daily(Client.t(), start_date :: Date.t()) ::
          {:ok, list(Api.StepsDaily.t()), Client.t()} | error()
  @spec steps_daily(Client.t(), start_date :: Date.t(), end_date :: Date.t()) ::
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
  Gets number of completed and goal steps per week.
  """
  @spec steps_weekly(Client.t()) :: {:ok, list(Api.StepsWeekly.t()), Client.t()} | error()
  @spec steps_weekly(Client.t(), end_date :: Date.t()) ::
          {:ok, list(Api.StepsWeekly.t()), Client.t()} | error()
  @spec steps_weekly(Client.t(), end_date :: Date.t(), weeks_count :: integer()) ::
          {:ok, list(Api.StepsWeekly.t()), Client.t()} | error()
  def steps_weekly(client, end_date \\ Date.utc_today(), weeks_count \\ 1) do
    client |> steps_weekly_req(end_date, weeks_count) |> response_as_data(Api.StepsWeekly)
  end

  def steps_weekly_req(client, end_date \\ Date.utc_today(), weeks_count \\ 1) do
    get(client,
      url: "/usersummary-service/stats/steps/weekly/:end_date/:weeks_count",
      path_params: [end_date: Date.to_iso8601(end_date), weeks_count: weeks_count]
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
  Gets latest activity
  """
  @spec last_activity(Client.t()) :: {:ok, Api.ActivityList.t(), Client.t()} | error()
  def last_activity(client) do
    case activities(client, 0, 1) do
      {:ok, [], _client} -> {:error, :not_found}
      {:ok, [activity | _], client} -> {:ok, activity, client}
      result -> result
    end
  end

  @doc """
  Gets activity with given ID.

  Note: this doesn't return the same data structure as a list of activities!
  """
  @spec activity(Client.t(), integer()) :: {:ok, Api.Activity.t(), Client.t()} | error()
  def activity(client, id), do: client |> activity_req(id) |> response_as_data(Api.Activity)

  def activity_req(client, id),
    do: get(client, url: "/activity-service/activity/:id", path_params: [id: id])

  @doc """
  Gets details for activitiy with given ID
  """
  @spec activity_details(Client.t(), integer()) ::
          {:ok, Api.ActivityDetails.t(), Client.t()} | error()
  def activity_details(client, id),
    do: client |> activity_details_req(id) |> response_as_data(Api.ActivityDetails)

  def activity_details_req(client, id),
    do: get(client, url: "/activity-service/activity/:id/details", path_params: [id: id])

  @doc """
  Gets activities
  """
  @spec activities(Client.t()) :: {:ok, list(Api.ActivityList.t()), Client.t()} | error()
  @spec activities(Client.t(), offset :: integer()) ::
          {:ok, list(Api.ActivityList.t()), Client.t()} | error()
  @spec activities(Client.t(), offset :: integer(), limit :: integer()) ::
          {:ok, list(Api.ActivityList.t()), Client.t()} | error()
  def activities(client, offset \\ 0, limit \\ 10) do
    client |> activities_req(offset, limit) |> response_as_data(Api.ActivityList)
  end

  def activities_req(client, offset, limit) do
    get(client,
      url: "/activitylist-service/activities/search/activities",
      params: [limit: limit, start: offset]
    )
  end

  @doc """
  Gets non-completed adhoc challenges.

  Supported options:
  - `:today_date` - optional date string sent as `todayDate`
  - `:gc_api` - use `/gc-api` prefixed path
  """
  @spec adhoc_challenges(Client.t(), keyword()) :: {:ok, list(map()), Client.t()} | error()
  def adhoc_challenges(client, opts \\ []) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           adhoc_challenges_req(client, opts),
         {:ok, challenges} <- decode_map_list(body) do
      {:ok, challenges, client}
    end
  end

  @spec adhoc_challenges_req(Client.t(), keyword()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def adhoc_challenges_req(client, opts \\ []) do
    get(client,
      url: maybe_gc_api_path("/adhocchallenge-service/adHocChallenge/nonCompleted", opts),
      params: maybe_today_date_param(opts)
    )
  end

  @doc """
  Gets details of a single adhoc challenge.

  Supported options:
  - `:today_date` - optional date string sent as `todayDate`
  - `:gc_api` - use `/gc-api` prefixed path
  """
  @spec adhoc_challenge(Client.t(), String.t(), keyword()) :: {:ok, map(), Client.t()} | error()
  def adhoc_challenge(client, challenge_id, opts \\ []) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           adhoc_challenge_req(client, challenge_id, opts),
         true <- is_map(body) do
      {:ok, body, client}
    else
      {:ok, %Req.Response{body: body}, _client} -> {:error, {:invalid_response, body}}
      false -> {:error, :invalid_response}
      error -> error
    end
  end

  @spec adhoc_challenge_req(Client.t(), String.t(), keyword()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def adhoc_challenge_req(client, challenge_id, opts \\ []) do
    get(client,
      url: maybe_gc_api_path("/adhocchallenge-service/adHocChallenge/:challenge_id", opts),
      path_params: [challenge_id: challenge_id],
      params: maybe_today_date_param(opts)
    )
  end

  @doc """
  Gets activities feed by owner display name.

  Supported options:
  - `:start` - pagination offset (default `1`)
  - `:limit` - pagination limit (default `20`)
  - `:gc_api` - use `/gc-api` prefixed path
  """
  @spec owner_activities(Client.t(), String.t(), keyword()) ::
          {:ok, list(map()), Client.t()} | error()
  def owner_activities(client, owner_display_name, opts \\ []) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           owner_activities_req(client, owner_display_name, opts) do
      {:ok, activity_list_from_body(body), client}
    end
  end

  @spec owner_activities_req(Client.t(), String.t(), keyword()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def owner_activities_req(client, owner_display_name, opts \\ []) do
    get(client,
      url: maybe_gc_api_path("/activitylist-service/activities/:owner_display_name", opts),
      path_params: [owner_display_name: owner_display_name],
      params: [
        start: option_value(opts, [:start], 1),
        limit: option_value(opts, [:limit], 20)
      ]
    )
  end

  @doc """
  Searches activities with Garmin filters.

  Supported options:
  - `:start` (default `0`)
  - `:limit` (default `20`)
  - `:user_profile_id` (maps to `userProfileId`)
  - `:include_followed` (maps to `includeFollowed`)
  - `:start_date` (maps to `startDate`)
  - `:end_date` (maps to `endDate`)
  - `:gc_api` - use `/gc-api` prefixed path
  """
  @spec activities_search(Client.t(), keyword()) :: {:ok, list(map()), Client.t()} | error()
  def activities_search(client, opts \\ []) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           activities_search_req(client, opts) do
      {:ok, activity_list_from_body(body), client}
    end
  end

  @spec activities_search_req(Client.t(), keyword()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def activities_search_req(client, opts \\ []) do
    params =
      []
      |> Keyword.put(:start, option_value(opts, [:start], 0))
      |> Keyword.put(:limit, option_value(opts, [:limit], 20))
      |> maybe_put_param(
        :userProfileId,
        option_value(opts, [:user_profile_id, :userProfileId], nil)
      )
      |> maybe_put_param(
        :includeFollowed,
        option_value(opts, [:include_followed, :includeFollowed], nil)
      )
      |> maybe_put_param(:startDate, option_value(opts, [:start_date, :startDate], nil))
      |> maybe_put_param(:endDate, option_value(opts, [:end_date, :endDate], nil))

    get(client,
      url: maybe_gc_api_path("/activitylist-service/activities/search/activities", opts),
      params: params
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
  {:ok, [{_filename, data}]} = :zip.extract(zip, [:memory])
  # Use https://github.com/arathunku/ext_fit to decode FIT file
  {:ok, records} = data |> ExtFit.Decode.decode()
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

  @doc """
  Returns user settings
  """
  @spec user_settings(Client.t()) :: {:ok, Api.UserSettings.t(), Client.t()} | error()
  def user_settings(client),
    do: client |> user_settings_req() |> response_as_data(Api.UserSettings)

  def user_settings_req(client),
    do: get(client, url: "/userprofile-service/userprofile/user-settings")

  @doc """
  Gets sleep data for a given day.
  """
  @spec sleep_daily(Client.t(), username :: String.t()) ::
          {:ok, list(Api.SleepDaily.t()), Client.t()} | error()
  @spec sleep_daily(Client.t(), username :: String.t(), date :: Date.t()) ::
          {:ok, list(Api.SleepDaily.t()), Client.t()} | error()
  @spec sleep_daily(Client.t(), username :: String.t(), date :: Date.t(), integer()) ::
          {:ok, list(Api.SleepDaily.t()), Client.t()} | error()
  def sleep_daily(client, username, date \\ Date.utc_today(), buffer_minutes \\ 60) do
    client |> sleep_daily_req(username, date, buffer_minutes) |> response_as_data(Api.SleepDaily)
  end

  def sleep_daily_req(client, username, date \\ Date.utc_today(), buffer_minutes \\ 60) do
    get(client,
      url: "/wellness-service/wellness/dailySleepData/:username",
      params: [nonSleepBufferMinutes: buffer_minutes, date: Date.to_iso8601(date)],
      path_params: [username: username]
    )
  end

  @doc """
  Gets sleep data for the authenticated user without a display name.
  """
  @spec sleep_daily_current(Client.t()) :: {:ok, map(), Client.t()} | error()
  @spec sleep_daily_current(Client.t(), Date.t()) :: {:ok, map(), Client.t()} | error()
  def sleep_daily_current(client, date \\ Date.utc_today()) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           sleep_daily_current_req(client, date),
         true <- is_map(body) do
      {:ok, body, client}
    else
      {:ok, %Req.Response{body: body}, _client} -> {:error, {:invalid_response, body}}
      false -> {:error, :invalid_response}
      error -> error
    end
  end

  @spec sleep_daily_current_req(Client.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  @spec sleep_daily_current_req(Client.t(), Date.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def sleep_daily_current_req(client, date \\ Date.utc_today()) do
    get(client,
      url: "/sleep-service/sleep/dailySleepData",
      params: [nonSleepBufferMinutes: 60, date: Date.to_iso8601(date)]
    )
  end

  @doc """
  Gets HRV data for a given day.
  """
  @spec hrv_daily(Client.t()) :: {:ok, map(), Client.t()} | error()
  @spec hrv_daily(Client.t(), Date.t()) :: {:ok, map(), Client.t()} | error()
  def hrv_daily(client, date \\ Date.utc_today()) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <- hrv_daily_req(client, date),
         true <- is_map(body) do
      {:ok, body, client}
    else
      {:ok, %Req.Response{body: body}, _client} -> {:error, {:invalid_response, body}}
      false -> {:error, :invalid_response}
      error -> error
    end
  end

  @spec hrv_daily_req(Client.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  @spec hrv_daily_req(Client.t(), Date.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def hrv_daily_req(client, date \\ Date.utc_today()) do
    get(client,
      url: "/hrv-service/hrv/:date",
      path_params: [date: Date.to_iso8601(date)]
    )
  end

  @doc """
  Gets aggregated training status for a given day.
  """
  @spec training_status(Client.t()) :: {:ok, map(), Client.t()} | error()
  @spec training_status(Client.t(), Date.t()) :: {:ok, map(), Client.t()} | error()
  def training_status(client, date \\ Date.utc_today()) do
    with {:ok, %Req.Response{status: 200, body: body}, client} <-
           training_status_req(client, date),
         true <- is_map(body) do
      {:ok, body, client}
    else
      {:ok, %Req.Response{body: body}, _client} -> {:error, {:invalid_response, body}}
      false -> {:error, :invalid_response}
      error -> error
    end
  end

  @spec training_status_req(Client.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  @spec training_status_req(Client.t(), Date.t()) ::
          {:ok, Req.Response.t(), Client.t()} | {:error, Req.Response.t()}
  def training_status_req(client, date \\ Date.utc_today()) do
    get(client,
      url: "/metrics-service/metrics/trainingstatus/aggregated/:date",
      path_params: [date: Date.to_iso8601(date)]
    )
  end

  defp maybe_gc_api_path(path, opts) do
    if option_value(opts, [:gc_api, :gc_api?], false) do
      "/gc-api#{path}"
    else
      path
    end
  end

  defp maybe_today_date_param(opts) do
    case option_value(opts, [:today_date, :todayDate], nil) do
      nil -> []
      today_date -> [todayDate: today_date]
    end
  end

  defp decode_map_list(body) when is_list(body) do
    {:ok, Enum.filter(body, &is_map/1)}
  end

  defp decode_map_list(body) do
    {:error, {:invalid_response, body}}
  end

  defp activity_list_from_body(body) when is_list(body) do
    Enum.filter(body, &is_map/1)
  end

  defp activity_list_from_body(body) when is_map(body) do
    body
    |> first_list_for_keys([
      "activityList",
      :activityList,
      "activities",
      :activities,
      "results",
      :results,
      "data",
      :data
    ])
    |> Enum.filter(&is_map/1)
  end

  defp activity_list_from_body(_body), do: []

  defp first_list_for_keys(payload, keys) do
    Enum.find_value(keys, [], fn key ->
      case Map.get(payload, key) do
        value when is_list(value) -> value
        _ -> nil
      end
    end) || []
  end

  defp option_value(opts, keys, default) do
    Enum.find_value(keys, default, fn key ->
      case Keyword.fetch(opts, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, key, value), do: Keyword.put(params, key, value)
end
