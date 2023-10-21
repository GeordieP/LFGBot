defmodule LfgBot.Discord.Interactions do
  require Logger
  alias Nostrum.Api, as: DiscordAPI
  alias LfgBot.LfgSystem
  alias LfgBot.Discord.Consumer
  alias LfgBot.LfgSystem.Session
  alias LfgBot.LfgSystem.RegisteredGuildChannel
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.ApplicationCommandInteractionData
  alias Nostrum.Struct.User
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.Component.ActionRow
  alias Nostrum.Struct.Component.Button
  alias Nostrum.Struct.Embed

  @bot_ets_table :lfg_bot_table

  def install_server_commands(guilds, bot_user_id) do
    # store bot user ID in ETS for later reference
    true = :ets.insert(@bot_ets_table, {"bot_user_id", bot_user_id})

    command = %{
      name: Consumer.command_name(),
      description: "Initialize LFG Bot in the current channel"
    }

    # on startup, delete all existing commands we've previously created, and re-register them.
    # this ensures no duplicates are registered, and any command name changes are propagated to servers.
    Enum.each(guilds, fn %{id: guild_id} ->
      {:ok, commands} = DiscordAPI.get_guild_application_commands(guild_id)

      Enum.each(commands, fn %{id: command_id} ->
        DiscordAPI.delete_guild_application_command(guild_id, command_id)
      end)

      DiscordAPI.create_guild_application_command(guild_id, command)
    end)

    {:ok}
  end

  def shuffle_teams(%Interaction{} = interaction, invoker_id, session_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.shuffle_teams(session, Snowflake.dump(invoker_id))

    DiscordAPI.edit_message(
      Snowflake.cast!(session.channel_id),
      Snowflake.cast!(session.message_id),
      embeds: build_session_msg_embeds(session)
    )

    DiscordAPI.create_interaction_response(interaction, %{type: 7})
  end

  def start_session(
        %Interaction{} = interaction,
        guild_id,
        channel_id,
        leader_user_id,
        leader_user_name
      ) do
    {:ok, %{id: setup_msg_id}} =
      DiscordAPI.create_message(channel_id, content: "Setting up a new game...")

    try do
      {:ok, session} =
        Session.new(%{
          guild_id: Snowflake.dump(guild_id),
          channel_id: Snowflake.dump(channel_id),
          message_id: Snowflake.dump(setup_msg_id),
          leader_user_id: Snowflake.dump(leader_user_id),
          leader_user_name: leader_user_name
        })

      {:ok, _message} =
        DiscordAPI.edit_message(channel_id, setup_msg_id,
          content: "",
          embeds: build_session_msg_embeds(session),
          components: build_session_buttons(session)
        )

      DiscordAPI.create_interaction_response(interaction, %{type: 6})
    rescue
      e ->
        DiscordAPI.delete_message(channel_id, setup_msg_id)
        raise e
    end
  end

  def end_session(%Interaction{} = interaction, invoker_id, session_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)

    {:ok, %{state: :ended} = session} =
      Session.terminate_session(session, Snowflake.dump(invoker_id))

    DiscordAPI.delete_message(
      Snowflake.cast!(session.channel_id),
      Snowflake.cast!(session.message_id)
    )

    DiscordAPI.create_interaction_response(interaction, %{type: 6})
  end

  def player_join(%Interaction{} = interaction, %User{} = user, session_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)

    case Session.player_join(session, dump_user(user)) do
      {:ok, session} ->
        {:ok, _msg} =
          DiscordAPI.edit_message(
            Snowflake.cast!(session.channel_id),
            Snowflake.cast!(session.message_id),
            embeds: build_session_msg_embeds(session)
          )

        DiscordAPI.create_interaction_response(interaction, %{type: 7})

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        case List.first(errors) do
          # player is already on a team
          %Ash.Error.Changes.InvalidChanges{message: message, path: [:player_team]} ->
            Logger.debug(
              "[NOOP] [PLAYER JOIN] #{message} | player: #{user.username} #{user.id} | session id: #{session_id}"
            )

            DiscordAPI.create_interaction_response(interaction, %{type: 7})

          # player is already in the reserve list
          %Ash.Error.Changes.InvalidChanges{message: message, path: [:player_reserve]} ->
            Logger.debug(
              "[NOOP] [PLAYER JOIN] #{message} | player: #{user.username} #{user.id} | session id: #{session_id}"
            )

            DiscordAPI.create_interaction_response(interaction, %{type: 7})
        end
    end
  end

  def player_leave(%Interaction{} = interaction, invoker_id, session_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.player_leave(session, Snowflake.dump(invoker_id))

    DiscordAPI.edit_message(
      Snowflake.cast!(session.channel_id),
      Snowflake.cast!(session.message_id),
      embeds: build_session_msg_embeds(session)
    )

    DiscordAPI.create_interaction_response(interaction, %{type: 7})
  end

  # ---

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
end
