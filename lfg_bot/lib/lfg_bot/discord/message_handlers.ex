defmodule LfgBot.Discord.MessageHandlers do
  require Logger
  alias LfgBot.LfgSystem.RegisteredGuildChannel
  alias Nostrum.Struct.Embed
  alias Nostrum.Snowflake
  alias Nostrum.Api, as: DiscordAPI
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Component.ActionRow
  alias Nostrum.Struct.Component.Button
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Message

  def registration_message(reg_id, channel_id, message_id) do
    try do
      {:ok, %RegisteredGuildChannel{} = reg_chan} = RegisteredGuildChannel.by_id(reg_id)

      {:ok, %RegisteredGuildChannel{} = _reg_chan} =
        RegisteredGuildChannel.update_message_id(reg_chan, Snowflake.dump(message_id))

      {:ok, %Message{}} =
        DiscordAPI.edit_message(channel_id, message_id,
          content: "",
          embeds: build_registration_msg_embeds(),
          components: build_registration_msg_components()
        )

      {:ok}
    rescue
      e ->
        Logger.error("failed to attach to the registration message")
        DiscordAPI.delete_message(channel_id, message_id)
        reraise e, __STACKTRACE__
    end
  end

  # ---

  defp build_registration_msg_embeds() do
    introduction_message_embed =
      %Embed{}
      |> Embed.put_author(
        "LFG Bot",
        "https://github.com/geordiep/LFGBot",
        "https://cdn.discordapp.com/app-icons/1160972219061645312/71ce8a6c1ccac060cfb32ed81d4b66ed.png"
      )
      |> Embed.put_color(0xFF6600)
      |> Embed.put_description(build_introduction_msg())

    [introduction_message_embed]
  end

  defp build_registration_msg_components() do
    # docs:
    # button options - presumably default discord options: https://discord.com/developers/docs/interactions/message-components#button-object-button-structure
    new_game_component_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("New Group", "LFGBOT_START_SESSION",
          style: Nostrum.Constants.ButtonStyle.success()
        )
      )

    [new_game_component_row]
  end

  defp build_introduction_msg do
    """
    *A Discord bot for inhouse games*

    **Click `New Group` below to start a session!**

    The bot will send a message with buttons to join/leave the group, shuffle teams, and end the session.

    `🔒 Locked` buttons can only be used by the group creator.

    Have fun!
    """
  end
end
