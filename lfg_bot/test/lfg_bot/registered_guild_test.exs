defmodule LfgBot.RegisteredGuildChannelTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.RegisteredGuildChannel

  test "allows fetching a registered guild by guild id and channel id" do
    {:ok, _first_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:ok, second_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "second guild",
        channel_id: "second channel"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get_by_guild_and_channel("second guild", "second channel")

    assert found.id == second_channel.id
  end

  test "bang function returns nil for an unrecognized guild" do
    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "second guild",
        channel_id: "second channel"
      })

    assert {:error, %Ash.Error.Query.NotFound{}} =
             RegisteredGuildChannel.get_by_guild_and_channel("third guild", "third channel")
  end
end

# More tests ideas:
#
# - since the :unique_server identity consists of [:guild_id, :channel_id, :message_id],
#   what happens when two channels in the same guild are registered, but neither successfully set the message id?
#   i.e. test: register two channel ids with the same guild id, and nil message id. match expected result.
#
# - test: ensure the identity works. register two different channels with the same guild id,
#   and then try to register one of them again. should return error.
