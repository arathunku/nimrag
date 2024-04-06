defmodule NimragTest do
  use ExUnit.Case
  alias Nimrag
  import Nimrag.ApiHelper

  doctest Nimrag

  test "#profile" do
    Req.Test.stub(Nimrag.Api, fn conn ->
      Req.Test.json(conn, read_response_fixture(conn))
    end)

    assert {:ok, profile, _client} = Nimrag.profile(client())
  end
end
