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

  test "allows fetching a registered guild by guild id and channel id" do
    {:ok, guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel",
        intro_message_id: "first message"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get(%{guild_id: "first guild", intro_channel_id: "first channel"})

    assert found.id == guild_channel.id
  end

  test "allows fetching a registered guild by guild id and channel id and message id" do
    {:ok, guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel",
        intro_message_id: "first message"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get(%{
        guild_id: "first guild",
        intro_channel_id: "first channel",
        intro_message_id: "first message"
      })

    assert found.id == guild_channel.id
  end
end
