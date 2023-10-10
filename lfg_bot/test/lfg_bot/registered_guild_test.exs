defmodule LfgBot.RegisteredGuildChannelTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.RegisteredGuildChannel

  test "disallows registering the same guild channel more than once" do
    {:ok, guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel",
        intro_message_id: "first message"
      })

    {:error, %Ash.Error.Invalid{errors: errors}} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel",
        intro_message_id: "first message"
      })

    error = Enum.at(errors, 0)
    assert error.message =~ "been taken"
  end
end
