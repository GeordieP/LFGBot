defmodule LfgBot.Discord.Consumer do
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
  alias LfgBot.Discord.InteractionHandlers
  alias LfgBot.Discord.MessageHandlers

  # bot permissions = send messages, create public threads, manage threads, read message history, add reactions, use slash commands
  # @bot_invite_url "https://discord.com/api/oauth2/authorize?client_id=1160972219061645312&permissions=53687158848&scope=bot"
  @bot_ets_table :lfg_bot_table
  @command_name "lfginit"
  def command_name, do: @command_name

  def handle_event({:READY, %{guilds: guilds, user: %{id: bot_user_id, bot: true}}, _ws_state}) do
    Logger.debug("[DISCORD EVENT] [READY] installing server commands...")
    {:ok} = InteractionHandlers.install_server_commands(guilds, bot_user_id)
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

  defp build_session_msg_embeds(%Session{} = session) do
    alias Nostrum.Struct.Embed

    [team_one, team_two] = session.teams

    player_count = length(team_one["players"]) + length(team_two["players"])

    player_count_label =
      case player_count do
        0 -> ""
        1 -> "(1 player)"
        _ -> "(#{player_count} players)"
      end

    name_label =
      if String.last(session.leader_user_name) == "s" do
        session.leader_user_name <> "' group " <> player_count_label
      else
        session.leader_user_name <> "'s group " <> player_count_label
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
