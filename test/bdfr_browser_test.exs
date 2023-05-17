defmodule BdfrBrowserTest do
  use ExUnit.Case
  doctest BdfrBrowser

  test "greets the world" do
    assert BdfrBrowser.hello() == :world
  end
end
