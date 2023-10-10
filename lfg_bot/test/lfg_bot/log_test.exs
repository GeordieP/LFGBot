defmodule LfgBot.LogTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.Log

  test "logs and retrieves messages" do
    Log.new(%{type: :info, data: to_string(inspect(%{testing: "one two three"}))})

    {:ok, logs} = Log.read()
    [first_log] = logs
    assert first_log.type == :info
    assert first_log.data =~ "testing"
    assert first_log.data =~ "three"
  end

  test "retrieves messages of a single type" do
    Log.new(%{type: :info, data: "one"})
    Log.new(%{type: :info, data: "two"})
    Log.new(%{type: :info, data: "three"})
    Log.new(%{type: :info, data: "four"})

    Log.new(%{type: :error, data: "error one"})
    Log.new(%{type: :error, data: "error two"})
    Log.new(%{type: :error, data: "error three"})

    {:ok, logs} = Log.read_error()
    [first_log, second_log, third_log] = logs

    assert first_log.type == :error
    assert second_log.type == :error
    assert third_log.type == :error
  end
end
