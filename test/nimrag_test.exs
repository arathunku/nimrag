defmodule NimragTest do
  use ExUnit.Case
  alias Nimrag
  import Nimrag.ApiHelper

  doctest Nimrag

  test "#profile" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, _profile, _client} = Nimrag.profile(client())
  end

  test "#steps_daily" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, _steps_daily, _client} =
             Nimrag.steps_daily(client(), ~D|2024-04-06|, ~D|2024-04-06|)
  end

  test "#activities" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, _activities, _client} = Nimrag.activities(client(), 0, 1)
  end

  test "#user_settings" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, _user_settings, _client} = Nimrag.user_settings(client())
  end

  test "#steps_weekly" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, steps_weekly, _client} = Nimrag.steps_weekly(client(), ~D|2024-05-01|, 4)

    assert Enum.count(steps_weekly) == 4
    assert hd(steps_weekly).calendar_date == ~D[2024-04-04]
    # Garmin is very strange with "weekly" grouping...
    assert List.last(steps_weekly).calendar_date == ~D[2024-04-25]
  end

  test "#sleep_daily" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %Nimrag.Api.SleepDaily{}, _client} =
             Nimrag.sleep_daily(client(), "arathunku", ~D|2024-05-01|, 60)
  end

  test "#activity" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %Nimrag.Api.Activity{}, _client} = Nimrag.activity(client(), 15_205_844_761)
  end

  test "#activity_details" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %Nimrag.Api.ActivityDetails{}, _client} =
             Nimrag.activity_details(client(), 15_205_844_761)
  end

  test "#adhoc_challenges" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, [challenge], _client} = Nimrag.adhoc_challenges(client())
    assert challenge["uuid"] == "challenge-1"
  end

  test "#adhoc_challenge" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %{"players" => [_player]}, _client} =
             Nimrag.adhoc_challenge(client(), "challenge-1")
  end

  test "#adhoc_challenge with gc_api option" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %{"source" => "gc-api"}, _client} =
             Nimrag.adhoc_challenge(client(), "challenge-1", gc_api: true)
  end

  test "#adhoc_challenge returns error tuple on non-200 response" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"error" => "not found"})
    end)

    assert {:error, %Req.Response{status: 404}} = Nimrag.adhoc_challenge(client(), "missing")
  end

  test "#owner_activities" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, [activity], _client} = Nimrag.owner_activities(client(), "owner-uuid")
    assert activity["ownerDisplayName"] == "owner-uuid"
  end

  test "#activities_search with filters" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, activities, _client} =
             Nimrag.activities_search(client(),
               start: 0,
               limit: 10,
               user_profile_id: 35,
               include_followed: true
             )

    assert is_list(activities)
    assert Enum.count(activities) == 1
  end

  test "#sleep_daily_current" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %{"dailySleepDTO" => sleep}, _client} =
             Nimrag.sleep_daily_current(client(), ~D[2024-05-01])

    assert sleep["sleepTimeSeconds"] == 24_900
  end

  test "#hrv_daily" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %{"hrvSummary" => summary}, _client} = Nimrag.hrv_daily(client(), ~D[2024-05-01])
    assert summary["weeklyAvg"] == 48
    assert summary["status"] == "BALANCED"
  end

  test "#hrv_daily returns error tuple on non-200 response" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"error" => "not found"})
    end)

    assert {:error, %Req.Response{status: 404}} = Nimrag.hrv_daily(client(), ~D[2024-05-01])
  end

  test "#training_status" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, %{"mostRecentTrainingStatus" => status}, _client} =
             Nimrag.training_status(client(), ~D[2024-05-01])

    assert is_map(status["latestTrainingStatusData"])
  end

  test "#training_status returns error tuple on non-200 response" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{"error" => "not found"})
    end)

    assert {:error, %Req.Response{status: 404}} = Nimrag.training_status(client(), ~D[2024-05-01])
  end
end
