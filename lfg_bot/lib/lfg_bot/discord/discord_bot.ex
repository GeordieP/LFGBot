defmodule LfgBot.Discord.Bot do
  use Nostrum.Consumer
  alias Nostrum.Api

  # bot permissions = send messages, create public threads, manage threads, read message history, add reactions, use slash commands
  # @bot_invite_url "https://discord.com/api/oauth2/authorize?client_id=1160972219061645312&permissions=53687158848&scope=bot"
  # bot user id aka application id
  @bot_user_id 1_160_972_219_061_645_312

  # ignore messages from the bot
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) when msg.author.id == @bot_user_id,
    do: :noop

  def handle_event({:READY, %{guilds: guilds}, _ws_state}) do
    command = %{
      name: "lfginit",
      description:
        "Tell LFG Bot to register or un-register the current channel. Registering only needs to be done once.",
      options: [
        %{
          # reference for type numbers: https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-types
          # more reference for type numbers: https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-type
          type: 3,
          name: "register",
          description:
            "whether or not the bot should use this channel to manage LFG groups and games",
          required: true,
          choices: [
            %{
              name: "Register",
              value: "unregister"
            },
            %{
              name: "Un-Register",
              value: "unregister"
            }
          ]
        }
      ]
    }

    # on startup, delete all existing commands we've previously created, and re-register
    # this is probably not necessary, but keeps things clean while developing.
    Enum.each(guilds, fn %{id: guild_id} ->
      {:ok, commands} = Nostrum.Api.get_guild_application_commands(guild_id)

      Enum.each(commands, fn %{id: command_id} ->
        Nostrum.Api.delete_guild_application_command(guild_id, command_id)
      end)

      Nostrum.Api.create_guild_application_command(guild_id, command)
    end)
  end

  # TODO: an interaction create handler that matches on LFGBOT_START_GAME
  def handle_event(
        {:INTERACTION_CREATE,
         %Nostrum.Struct.Interaction{channel_id: channel_id, data: data} = interaction, _}
      ) do
    import Bitwise

    IO.puts("INTERACTION_CREATE in channel #{channel_id}")
    IO.inspect(interaction)

    alias Nostrum.Struct.Component.ActionRow
    alias Nostrum.Struct.Component.Button

    # docs:
    # button options - presumably default discord options: https://discord.com/developers/docs/interactions/message-components#button-object-button-structure
    action_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("Start game", "LFGBOT_START_GAME",
          style: Nostrum.Constants.ButtonStyle.primary(),
          emoji: %{name: "🔥"}
        )
      )

    # response docs:
    # type: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
    # data: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-data-structure
    # data.flags: https://discord.com/developers/docs/resources/channel#message-object-message-flags
    response = %{
      # ChannelMessageWithSource
      type: 4,
      data: %{
        content: "Channel registered",
        flags: 1 <<< 6,
        components: [action_row]
      }
    }

    IO.puts("sending response:")
    IO.inspect(response)
    Api.create_interaction_response(interaction, response)
  end

  def handle_event({:MESSAGE_CREATE, msg, ws_state}) do
    unless msg.author.bot do
      IO.puts("got message event. message is:")
      IO.puts("---")
      IO.inspect(msg)
      IO.puts("---")
    else
      IO.puts("got a bot message event")
      IO.puts("---")
      IO.inspect(msg)
      IO.puts("---")
    end
  end

  def handle_event(_), do: :noop
end
