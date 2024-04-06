defmodule Nimrag do
  alias Nimrag.Api

  @type error :: {atom, any}

  @moduledoc """
  All functions here to call Garmin's API.

  They will return {:ok, Struct, client} or {:error, error}.

  Client is always returned on success to keep the OAuth2 token updated.
  """

  @spec profile(Client.t()) :: {:ok, Api.Profile.t(), Client.t()} | error
  def profile(client) do
    Api.get(client, url: "/userprofile-service/socialProfile")
    |> as_api_data(Api.Profile)
  end

  @spec steps_daily(Client.t()) :: {:ok, list(Api.DailySteps.t()), Client.t()} | error
  @spec steps_daily(Client.t(), start_day :: Date.t()) :: {:ok, list(Api.DailySteps.t()), Client.t()} | error
  @spec steps_daily(Client.t(), start_day :: Date.t(), end_day :: Date.t()) :: {:ok, list(Api.DailySteps.t()), Client.t()} | error
  def steps_daily(client, start_date \\ Date.utc_today(), end_date \\ Date.utc_today()) do
    Api.get(client,
      url: "/usersummary-service/stats/steps/daily/:start_date/:end_date",
      path_params: [start_date: Date.to_iso8601(start_date), end_date: Date.to_iso8601(end_date)]
    )
    |> as_api_data(Api.StepsDaily)
  end

  def user_summary(client, date \\ Date.utc_today()) do
    Api.get(client,
      url: "/usersummary-service/usersummary/daily",
      params: [calendarDate: Date.to_iso8601(date)]
    )
    |> as_api_data(Api.UserSummaryDaily)
  end

  def last_activity(client) do
    with {:ok, [activity | _], client} <- activities(client, 0, 1) do
      {:ok, activity, client}
    end
  end

  def activities(client, start \\ 0, limit \\ 10) do
    Api.get(client,
      url: "/activitylist-service/activities/search/activities",
      params: [limit: limit, start: start]
    )
    |> as_api_data(Api.Activity)
  end

  defp as_api_data({:ok, %Req.Response{status: 200, body: body}, client}, struct_module) do
    with {:ok, data} <- as_api_data(body, struct_module) do
      {:ok, data, client}
    end
  end

  defp as_api_data({:error, error}, _struct_module), do: {:error, error}

  defp as_api_data(body, struct_module) when is_map(body) do
    case struct_module.from_api_response(body) do
      {:ok, struct} -> {:ok, struct}
      {:error, error} -> {:error, {error, body}}
    end
  end

  defp as_api_data(body, struct_module) when is_list(body) do
    structs =
      Enum.map(body, fn element ->
        case struct_module.from_api_response(element) do
          {:ok, struct} -> struct
          {:error, error} -> {:error, {error, element}}
        end
      end)

    first_error =
      Enum.find(structs, fn
        {:error, _} -> true
        _ -> false
      end)

    first_error || {:ok, structs}
  end
end
