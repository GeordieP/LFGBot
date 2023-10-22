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

  test "updates an existing channel with a message id" do
    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get_by_guild_and_channel("first guild", "first channel")

    {:ok, %RegisteredGuildChannel{} = found} =
      Ash.Changeset.for_update(found, :update, %{message_id: "test message id"})
      |> LfgSystem.update()

    assert "test message id" == found.message_id
  end

  test "updates an existing channel with a message id using code interface" do
    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.get_by_guild_and_channel("first guild", "first channel")

    {:ok, %RegisteredGuildChannel{} = found} =
      RegisteredGuildChannel.update_message_id(found, "test message id")

    assert("test message id" == found.message_id)
  end

  test "get a reg channel by db id" do
    {:ok, %{id: id}} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "second guild",
        channel_id: "second channel"
      })

    {:ok, found} = RegisteredGuildChannel.by_id(id)
    assert found.guild_id == "first guild"
  end

  test "disallows registering the same channel more than once" do
    {:ok, _guild_channel} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    {:error, %Ash.Error.Invalid{errors: errors}} =
      RegisteredGuildChannel.new(%{
        guild_id: "first guild",
        channel_id: "first channel"
      })

    assert %Ash.Error.Changes.InvalidAttribute{field: :guild_id, message: message} =
             List.first(errors)

    assert message =~ "taken"
  end
end
