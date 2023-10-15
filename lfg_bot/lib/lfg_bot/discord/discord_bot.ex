defmodule LfgBot.Discord.Bot do
  use Nostrum.Consumer

  require Logger
  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.Session
  alias LfgBot.LfgSystem.RegisteredGuildChannel
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.ApplicationCommandInteractionData
  alias Nostrum.Struct.User
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.Component.ActionRow
  alias Nostrum.Struct.Component.Button
  alias Nostrum.Struct.Embed

  # bot permissions = send messages, create public threads, manage threads, read message history, add reactions, use slash commands
  # @bot_invite_url "https://discord.com/api/oauth2/authorize?client_id=1160972219061645312&permissions=53687158848&scope=bot"
  @command_name "lfginit"
  @bot_ets_table :lfg_bot_table

  def handle_event({:READY, %{guilds: guilds, user: %{id: bot_user_id, bot: true}}, _ws_state}) do
    # store bot user ID in ETS for later reference
    true = :ets.insert(:lfg_bot_table, {"bot_user_id", bot_user_id})

    command = %{
      name: @command_name,
      description: "Initialize LFG Bot in the current channel"
      # options:
      #   %{
      #     # reference for type numbers: https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-types
      #     # more reference for type numbers: https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-type
      #     type: 3,
      #     name: "register",
      #     description:
      #       "whether or not the bot should use this channel to manage LFG groups and games",
      #     required: true,
      #     choices: [
      #       %{
      #         name: "Register",
      #         value: "unregister"
      #       },
      #       %{
      #         name: "Un-Register",
      #         value: "unregister"
      #       }
      #     ]
      #   }
      # ]
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

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_SHUFFLE_TEAMS_" <> session_id
           }
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [SHUFFLE TEAMS] invoker: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.shuffle_teams(session, Snowflake.dump(invoker_id))

    Api.edit_message(Snowflake.cast!(session.channel_id), Snowflake.cast!(session.message_id),
      embeds: build_sesson_embeds(session)
    )

    Api.create_interaction_response(interaction, %{type: 7})
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_END_SESSION_" <> session_id
           }
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [END SESSION] invoker: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    {:ok, session} = LfgSystem.get(Session, session_id)

    {:ok, %{state: :ended} = session} =
      Session.terminate_session(session, Snowflake.dump(invoker_id))

    Api.create_interaction_response(interaction, %{type: 6})
    Api.delete_message(Snowflake.cast!(session.channel_id), Snowflake.cast!(session.message_id))
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: user,
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_PLAYER_JOIN_" <> session_id
           }
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [PLAYER JOIN] player: #{user.username} #{user.id} | session id: #{session_id}"
    )

    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.player_join(session, dump_user(user))

    Api.edit_message(Snowflake.cast!(session.channel_id), Snowflake.cast!(session.message_id),
      embeds: build_sesson_embeds(session)
    )

    Api.create_interaction_response(interaction, %{type: 7})
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_PLAYER_LEAVE_" <> session_id
           }
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [PLAYER LEAVE] player: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.player_leave(session, Snowflake.dump(invoker_id))

    Api.edit_message(Snowflake.cast!(session.channel_id), Snowflake.cast!(session.message_id),
      embeds: build_sesson_embeds(session)
    )

    Api.create_interaction_response(interaction, %{type: 7})
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           channel_id: channel_id,
           guild_id: guild_id,
           user: %{id: leader_user_id, username: leader_user_name},
           data: %ApplicationCommandInteractionData{custom_id: "LFGBOT_START_SESSION"}
         }, _ws_state}
      ) do
    Logger.debug("[DISCORD EVENT] [START SESSION] leader: #{leader_user_name} #{leader_user_id}")

    {:ok, %{id: setup_msg_id}} =
      Api.create_message(channel_id, content: "Setting up a new game...")

    with {:ok, session} <-
           Session.new(%{
             guild_id: Snowflake.dump(guild_id),
             channel_id: Snowflake.dump(channel_id),
             message_id: Snowflake.dump(setup_msg_id),
             leader_user_id: Snowflake.dump(leader_user_id),
             leader_user_name: leader_user_name
           }) do
      {:ok, _message} =
        Api.edit_message(channel_id, setup_msg_id,
          content: "",
          embeds: build_sesson_embeds(session),
          components: build_session_buttons(session)
        )
    else
      anything ->
        # TODO: log to error table
        IO.inspect(anything)
        Api.delete_message(channel_id, setup_msg_id)
    end
  end

  @doc """
  Handle the register channel event
  """
  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           channel_id: channel_id,
           guild_id: guild_id,
           user: %{id: invoker_user_id, username: invoker_user_name},
           data: %ApplicationCommandInteractionData{name: @command_name}
         } = interaction, _}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [REGISTER CHANNEL] invoker: #{invoker_user_name} #{invoker_user_id} | guild id: #{guild_id}"
    )

    # TODO: instead of crashing on the match below,
    #       match on {:ok, %{message_id: message_id}} and then
    #       ask the API if that message ID can be found.
    #       if it is found, the channel is already set up and already has a reg message.
    #       otherwise, we should send a new reg message.
    #
    # OLD:
    # # ensure we don't run any of this logic when the channel is found. just crash when a channel is found
    # {:error, %Ash.Error.Query.NotFound{}} =
    #   RegisteredGuildChannel.get_by_guild_and_channel(
    #     Snowflake.dump(guild_id),
    #     Snowflake.dump(channel_id)
    #   )

    # store this guild and channel combo, take the DB-generated ID to
    # send in the interaction response message
    {:ok, %RegisteredGuildChannel{id: reg_id}} =
      RegisteredGuildChannel.new(%{
        guild_id: Snowflake.dump(guild_id),
        channel_id: Snowflake.dump(channel_id)
      })

    import Bitwise
    # response docs:
    # type: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
    # data: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-data-structure
    # data.flags: https://discord.com/developers/docs/resources/channel#message-object-message-flags
    response = %{
      type: 4,
      data: %{
        # suppress notifications: flag 1<<12
        flags: 1 <<< 12,
        content: "LFGREG:" <> reg_id
      }
    }

    Api.create_interaction_response(interaction, response)
  end

  # messages from bots
  def handle_event(
        {:MESSAGE_CREATE,
         %{
           content: "LFGREG:" <> reg_chan_id,
           id: message_id,
           channel_id: channel_id,
           author: %{id: msg_user_id, bot: true}
         } = msg, _ws_state}
      ) do
    with [{"bot_user_id", bot_user_id}] <- :ets.lookup(:lfg_bot_table, "bot_user_id"),
         true = msg_user_id == bot_user_id,
         {:ok, %RegisteredGuildChannel{} = reg_chan} <-
           RegisteredGuildChannel.by_id(reg_chan_id),
         {:ok, %RegisteredGuildChannel{} = _reg_chan} <-
           RegisteredGuildChannel.update_message_id(reg_chan, Snowflake.dump(message_id)) do
      Api.edit_message(channel_id, message_id,
        content: "",
        embeds: build_registration_msg_embeds(),
        components: build_registration_msg_components()
      )
    else
      anything ->
        Logger.error("failed to attach to the registration message")
        Api.delete_message(channel_id, message_id)
        IO.inspect(anything)
    end
  end

  def handle_event(_), do: :noop

  # ------------------

  defp build_session_buttons(%{id: session_id}) do
    leader_buttons_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("Shuffle Teams", "LFGBOT_SHUFFLE_TEAMS_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.primary(),
          emoji: %{name: "🔒"}
        )
      )
      |> ActionRow.append(
        Button.interaction_button("End Session", "LFGBOT_END_SESSION_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.secondary(),
          emoji: %{name: "🔒"}
        )
      )

    user_buttons_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("Join Game", "LFGBOT_PLAYER_JOIN_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.success(),
          emoji: %{name: "🎮"}
        )
      )
      |> ActionRow.append(
        Button.interaction_button("Leave Game", "LFGBOT_PLAYER_LEAVE_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.secondary(),
          emoji: %{name: "🚶"}
        )
      )

    [leader_buttons_row, user_buttons_row]
  end

  defp build_sesson_embeds(%Session{} = session) do
    alias Nostrum.Struct.Embed

    [team_one, team_two] = session.teams

    name_label =
      if String.last(session.leader_user_name) == "s" do
        session.leader_user_name <> "' group"
      else
        session.leader_user_name <> "'s group"
      end

    teams_embed =
      %Embed{}
      |> Embed.put_title(name_label)
      |> Embed.put_color(0xFF6600)
      |> Embed.put_description("Click `Join Game` to join a team!")
      |> Embed.put_field("TEAM 1", build_team_string(team_one["players"]), true)
      |> Embed.put_field("TEAM 2", build_team_string(team_two["players"]), true)

    [teams_embed]
  end

  defp build_team_string([]), do: "*Empty*"

  defp build_team_string(team) when is_list(team),
    do:
      Enum.map_join(team, "\n", fn
        %{"username" => username} -> "- " <> username
        %{username: username} -> "- " <> username
      end)

  @doc """
  Dump a Nostrum user struct into a more compact
  struct compatible with the database.
  """
  defp dump_user(%User{} = user) do
    %{
      id: Snowflake.dump(user.id),
      username: user.username,
      discriminator: user.discriminator,
      avatar: user.avatar
    }
  end

  @doc """
  Cast a database user into a Nostrum-compatible struct.
  """
  defp cast_user(user) do
    %{
      id: Snowflake.cast!(user.id),
      username: user.username,
      discriminator: user.discriminator,
      avatar: user.avatar
    }
  end

  defp build_registration_msg_embeds() do
    introduction_message_embed =
      %Embed{}
      |> Embed.put_title("LFG Bot")
      # fields for later, once repo is public:
      # |> Embed.put_author("GP")
      # |> Embed.put_url("https://github.com/geordiep/lfg_bot")
      |> Embed.put_color(0xFF6600)
      |> Embed.put_description(introduction_message())

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

  defp introduction_message do
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
