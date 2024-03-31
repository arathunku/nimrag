defmodule NimragTest do
  use ExUnit.Case
  doctest Nimrag

  test "greets the world" do
    assert Nimrag.hello() == :world
  end
end
