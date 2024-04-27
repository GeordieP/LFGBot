defmodule LfgBot.Discord.Consumer do
  use Nostrum.Consumer
  require Logger

  alias Nostrum.Struct.{ApplicationCommandInteractionData, Interaction}
  alias LfgBot.Discord.{InteractionHandlers, CommandHandlers, MessageHandlers}

  # bot permissions = send messages, create public threads, manage threads, read message history, add reactions, use slash commands
  # @bot_invite_url "https://discord.com/api/oauth2/authorize?client_id=1160972219061645312&permissions=53687158848&scope=bot"

  ## Interaction Handlers
  ## ----------------

  def handle_event({:READY, %{guilds: guilds, user: %{id: bot_user_id, bot: true}}, _ws_state}) do
    # store bot user ID in ETS for later reference. Our code should be able to find out our ID at any time.
    true = :ets.insert(:lfg_bot_table, {"bot_user_id", bot_user_id})

    Logger.debug("[DISCORD EVENT] [READY] installing commands...")

    # DANGER: TEMP -------------------------------------------------------------
    # SECTION: reset all commands migration:
    #       we're migrating from guild commands to global commands, since we can
    #       easily bulk update those.
    #       after a deployed version deletes all commands, enable the code to install global commands.

    {:ok} = CommandHandlers.delete_all_global_commands()

    for %{id: guild_id} <- guilds do
      {:ok} = CommandHandlers.delete_all_guild_commands(guild_id)
    end

    # END: reset all commands migration
    # DANGER: TEMP -------------------------------------------------------------

    # NOTE: enable the lines below after the migration.
    # {:ok} = CommandHandlers.install_global_commands()
    # {:not_implemented} = CommandHandlers.install_guild_commands(guilds)
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           channel_id: channel_id,
           guild_id: guild_id,
           user: %{id: leader_user_id, username: leader_user_name},
           data: %ApplicationCommandInteractionData{custom_id: "LFGBOT_START_SESSION"}
         } = interaction, _ws_state}
      ) do
    Logger.debug("[DISCORD EVENT] [START SESSION] leader: #{leader_user_name} #{leader_user_id}")

    {:ok} =
      InteractionHandlers.start_session(
        interaction,
        guild_id,
        channel_id,
        leader_user_id,
        leader_user_name
      )
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

    {:ok} = InteractionHandlers.end_session(interaction, invoker_id, session_id)
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

    {:ok} = InteractionHandlers.player_join(interaction, user, session_id)
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

    {:ok} = InteractionHandlers.player_leave(interaction, invoker_id, session_id)
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

    {:ok} = InteractionHandlers.shuffle_teams(interaction, invoker_id, session_id)
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_KICK_INIT_" <> session_id
           }
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [KICK INIT] invoker: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    {:ok} = InteractionHandlers.initialize_player_kick(interaction, invoker_id, session_id)
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data:
             %ApplicationCommandInteractionData{
               custom_id: "LFGBOT_KICK_SELECT_" <> session_id
             } = data
         } = interaction, _ws_state}
      ) do
    Logger.debug(
      "[DISCORD EVENT] [KICK SELECT] invoker: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    %{resolved: %Nostrum.Struct.ApplicationCommandInteractionDataResolved{users: users}} = data
    # expect exactly one user
    [player_to_kick_id] = Map.keys(users)

    {:ok} =
      InteractionHandlers.select_player_to_kick(
        interaction,
        invoker_id,
        session_id,
        player_to_kick_id
      )
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           user: %{id: invoker_id, username: invoker_username},
           data: %ApplicationCommandInteractionData{
             custom_id: "LFGBOT_KICK_SUBMIT_" <> session_and_user_id
           }
         } = interaction, _ws_state}
      ) do
    [session_id, user_id] = String.split(session_and_user_id, "_")

    Logger.debug(
      "[DISCORD EVENT] [KICK SUBMIT] invoker: #{invoker_username} #{invoker_id} | session id: #{session_id}"
    )

    {:ok} = InteractionHandlers.kick_player(interaction, invoker_id, session_id, user_id)
  end

  ## Command Handlers
  ## ----------------

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           data: %ApplicationCommandInteractionData{}
         } = interaction, _}
      ) do
    # INFO: we forward all commands to the command handler module,
    #       rather than explicitly handling them here in the consumer like everything else.
    #       The reason for this is that the CommandHandlers module has module attributes for
    #       each of our command names, so they can be pattern matched on.
    #       To use them here in the consumer, we'd have to duplicate that code into this module.
    CommandHandlers.handle_command(interaction)
  end

  ## Message Handlers
  ## ----------------

  def handle_event(
        {:MESSAGE_CREATE,
         %{
           content: "LFGREG:" <> reg_id,
           id: message_id,
           channel_id: channel_id,
           author: %{id: author_id, bot: true}
         }, _ws_state}
      ) do
    [{"bot_user_id", bot_user_id}] = :ets.lookup(:lfg_bot_table, "bot_user_id")

    # TODO: remove dbg
    # TODO: remove dbg
    # TODO: remove dbg
    dbg(bot_user_id)

    if author_id == bot_user_id do
      {:ok} = MessageHandlers.registration_message(reg_id, channel_id, message_id)
    end
  end

  def handle_event(_), do: :noop
end
