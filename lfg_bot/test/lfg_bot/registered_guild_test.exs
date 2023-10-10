defmodule LfgBot.RegisteredGuildChannelTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.RegisteredGuildChannel

  test "disallows registering the same guild channel more than once" do
    {:ok, guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel"
      })

    {:error, %Ash.Error.Invalid{errors: errors}} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel"
      })

    error = Enum.at(errors, 0)
    assert error.message =~ "been taken"
  end

  test "allows fetching a registered guild by guild id and channel id" do
    {:ok, _first_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel"
      })

    {:ok, second_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "second guild",
        intro_channel_id: "second channel"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get_by_guild_and_channel("second guild", "second channel")

    assert found.id == second_channel.id
  end

  test "bang function returns nil for an unrecognized guild" do
    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        intro_channel_id: "first channel"
      })

    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "second guild",
        intro_channel_id: "second channel"
      })

    assert {:error, %Ash.Error.Query.NotFound{}} =
             RegisteredGuildChannel.get_by_guild_and_channel("third guild", "third channel")
  end
end
