defmodule TinyLfuTest do
  use ExUnit.Case
  doctest TinyLfu

  test "greets the world" do
    assert TinyLfu.hello() == :world
  end
end
