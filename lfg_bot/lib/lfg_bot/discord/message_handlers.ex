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
      |> Embed.put_title("LFG Bot")
      # fields for later, once repo is public:
      # |> Embed.put_author("GP")
      # |> Embed.put_url("https://github.com/geordiep/lfg_bot")
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
        Button.interaction_button("New Game", "LFGBOT_START_SESSION",
          style: Nostrum.Constants.ButtonStyle.success()
        )
      )

    [new_game_component_row]
  end

  defp build_introduction_msg do
    """
    A Discord bot for inhouse games
    *by <@84203400920563712>*

    **Click 'New Game' below to start a group!**
    The bot will send a message in this channel with buttons to join/leave the group, shuffle teams, and end the session.

    Buttons with the 🔒 emoji can only be used by the group creator.

    Have fun!
    """
  end
end
