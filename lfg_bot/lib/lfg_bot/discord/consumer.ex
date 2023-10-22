defmodule LfgBot.Discord.Consumer do
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.ApplicationCommandInteractionData
  alias LfgBot.Discord.InteractionHandlers
  alias LfgBot.Discord.MessageHandlers

  # bot permissions = send messages, create public threads, manage threads, read message history, add reactions, use slash commands
  # @bot_invite_url "https://discord.com/api/oauth2/authorize?client_id=1160972219061645312&permissions=53687158848&scope=bot"
  @command_name "lfginit"
  def command_name, do: @command_name

  ## Interaction Handlers
  ## ----------------

  def handle_event({:READY, %{guilds: guilds, user: %{id: bot_user_id, bot: true}}, _ws_state}) do
    Logger.debug("[DISCORD EVENT] [READY] installing server commands...")
    {:ok} = InteractionHandlers.install_server_commands(guilds, bot_user_id)
  end

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

    {:ok} = InteractionHandlers.register_channel(interaction, guild_id, channel_id)
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

    if author_id == bot_user_id do
      {:ok} = MessageHandlers.registration_message(reg_id, channel_id, message_id)
    end
  end

  def handle_event(_), do: :noop
end
