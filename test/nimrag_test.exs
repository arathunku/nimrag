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
end
