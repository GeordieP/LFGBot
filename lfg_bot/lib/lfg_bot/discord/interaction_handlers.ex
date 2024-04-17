defmodule LfgBot.Discord.InteractionHandlers do
  require Logger
  import Bitwise

  alias Nostrum.Api, as: DiscordAPI
  alias LfgBot.Discord.Consumer
  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.{Session, RegisteredGuildChannel}
  alias Nostrum.Struct.{Interaction, User, Message, Embed}
  alias Nostrum.Struct.Component.{ActionRow, Button}
  alias Nostrum.Snowflake

  # Interaction response docs:
  # type: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
  # data: https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-data-structure
  # data.flags: https://discord.com/developers/docs/resources/channel#message-object-message-flags

  def install_server_commands(guilds, bot_user_id) do
    # store bot user ID in ETS for later reference
    true = :ets.insert(:lfg_bot_table, {"bot_user_id", bot_user_id})

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

  def register_channel(%Interaction{} = interaction, guild_id, channel_id) do
    check_result = check_is_channel_registered(guild_id, channel_id)
    maybe_register_channel(check_result, interaction, guild_id, channel_id)
  end

  defp check_is_channel_registered(guild_id, channel_id) do
    db_result =
      RegisteredGuildChannel.get_by_guild_and_channel(
        Snowflake.dump(guild_id),
        Snowflake.dump(channel_id)
      )

    case db_result do
      {:ok, %{id: reg_id, message_id: message_id}} ->
        # guild & channel combination was found in the database! ask discord API if the message can still be accessed
        case DiscordAPI.get_channel_message(channel_id, Snowflake.cast!(message_id)) do
          {:ok, %Message{} = message} ->
            # guild & channel combination exists in the database, and the message is still accessible
            {:registered, message}

          {:error, %{status_code: 404}} ->
            # guild & channel combination exists in the database, but the message is no longer accessible;
            {:disconnected, reg_id}
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        # guild & channel combination was not found in the database
        {:unregistered}
    end
  end

  defp maybe_register_channel({:registered, %Message{} = message}, interaction, _, _) do
    DiscordAPI.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        # ephemeral: flag 1<<6
        flags: 1 <<< 6,
        content:
          "This channel has already been registered. To re-register, a moderator will need to delete this message: #{Message.to_url(message)}"
      }
    })
  end

  # :disconnected means the channel was previously registered, but the message is no longer accessible.
  defp maybe_register_channel({:disconnected, reg_id}, interaction, _, _) do
    send_registration_response(interaction, reg_id)
  end

  defp maybe_register_channel({:unregistered}, interaction, guild_id, channel_id) do
    db_result =
      RegisteredGuildChannel.new(%{
        guild_id: Snowflake.dump(guild_id),
        channel_id: Snowflake.dump(channel_id)
      })

    case db_result do
      {:ok, %RegisteredGuildChannel{id: reg_id}} ->
        send_registration_response(interaction, reg_id)

      {:error, error} ->
        DiscordAPI.create_interaction_response(interaction, %{
          type: 4,
          data: %{
            # ephemeral: flag 1<<6
            flags: 1 <<< 6,
            content:
              "Failed to register! Something went wrong when saving the RegisteredGuildChannel to the database"
          }
        })

        raise error
    end
  end

  defp send_registration_response(%Interaction{} = interaction, reg_id) do
    DiscordAPI.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        # suppress notifications: flag 1<<12
        flags: 1 <<< 12,
        content: "LFGREG:" <> reg_id
      }
    })
  end

  def start_session(
        %Interaction{} = interaction,
        guild_id,
        channel_id,
        leader_user_id,
        leader_user_name
      ) do
    {:ok, %{id: setup_msg_id}} =
      DiscordAPI.create_message(channel_id, content: "Setting up a new group...")

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
        reraise e, __STACKTRACE__
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

  def initialize_player_kick(%Interaction{} = interaction, invoker_id, session_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)

    if is_session_leader?(session, invoker_id) do
      DiscordAPI.create_interaction_response(interaction, %{
        type: 4,
        data: %{
          # ephemeral: flag 1<<6
          flags: 1 <<< 6,
          content: "Choose a player to kick",
          components: build_kick_player_components(session_id, nil)
        }
      })
    else
      raise "only the session leader can perform this action"
    end
  end

  def select_player_to_kick(interaction, invoker_id, session_id, player_to_kick_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)

    if is_session_leader?(session, invoker_id) do
      DiscordAPI.create_interaction_response(interaction, %{
        type: 7,
        data: %{
          components: build_kick_player_components(session_id, player_to_kick_id)
        }
      })
    else
      raise "only the session leader can perform this action"
    end
  end

  def kick_player(%Interaction{} = interaction, invoker_id, session_id, player_to_kick_id)
      when is_binary(player_to_kick_id) do
    {:ok, session} = LfgSystem.get(Session, session_id)
    {:ok, session} = Session.player_kick(session, Snowflake.dump(invoker_id), player_to_kick_id)

    {:ok, _message} =
      DiscordAPI.edit_message(
        Snowflake.cast!(session.channel_id),
        Snowflake.cast!(session.message_id),
        embeds: build_session_msg_embeds(session)
      )

    # ACK the interaction, then delete the 'kick player' message
    {:ok} = DiscordAPI.create_interaction_response(interaction, %{type: 6})
    DiscordAPI.delete_interaction_response(interaction)
  end

  # ---

  defp build_session_buttons(%{id: session_id}) do
    leader_buttons_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("Shuffle Teams", "LFGBOT_SHUFFLE_TEAMS_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.secondary(),
          emoji: %{name: "🔒"}
        )
      )
      |> ActionRow.append(
        Button.interaction_button("End Session", "LFGBOT_END_SESSION_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.secondary(),
          emoji: %{name: "🔒"}
        )
      )
      |> ActionRow.append(
        Button.interaction_button(
          "Kick Player",
          "LFGBOT_KICK_INIT_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.secondary(),
          emoji: %{name: "🔒"}
        )
      )

    user_buttons_row =
      ActionRow.action_row()
      |> ActionRow.append(
        Button.interaction_button("Join Group", "LFGBOT_PLAYER_JOIN_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.primary(),
          emoji: %{name: "🎮"}
        )
      )
      |> ActionRow.append(
        Button.interaction_button("Leave Group", "LFGBOT_PLAYER_LEAVE_" <> session_id,
          style: Nostrum.Constants.ButtonStyle.primary(),
          emoji: %{name: "🚶"}
        )
      )

    [user_buttons_row, leader_buttons_row]
  end

  defp build_session_msg_embeds(%Session{} = session) do
    [team_one, team_two] = session.teams

    player_count = length(team_one["players"]) + length(team_two["players"])

    player_count_label =
      case player_count do
        0 -> ""
        1 -> "(1 player)"
        _ -> "(#{player_count} players)"
      end

    name_label = tag_user(session.leader_user_id) <> "'s group " <> player_count_label
    description = "**#{name_label}**\n\nClick `🎮 Join Group` below to join a team!"

    teams_embed =
      %Embed{}
      |> Embed.put_color(0xFF6600)
      |> Embed.put_description(description)
      |> Embed.put_field("TEAM 1", build_team_string(team_one["players"]), true)
      # use an empty field to add some space between teams; makes the lists a bit more readable
      |> Embed.put_field("", "", true)
      |> Embed.put_field("TEAM 2", build_team_string(team_two["players"]), true)

    [teams_embed]
  end

  defp build_team_string([]), do: "*Empty*"

  defp build_team_string(team) when is_list(team),
    do:
      Enum.map_join(team, "\n", fn
        %{"id" => id} -> "- " <> tag_user(id)
        %{id: id} -> "- " <> tag_user(id)
      end)

  # Dump a Nostrum user struct into a more compact
  # struct compatible with the database.
  defp dump_user(%User{} = user) do
    %{
      id: Snowflake.dump(user.id),
      username: user.username,
      discriminator: user.discriminator,
      avatar: user.avatar
    }
  end

  defp tag_user(user_id) when is_binary(user_id), do: "<@#{user_id}>"

  defp build_kick_player_components(session_id, player_to_kick_id) do
    select_menu =
      ActionRow.action_row(
        components: [
          # NOTE: seems that using the select_menu function doesn't actually let you use type 5, it always sends a type 3
          %Nostrum.Struct.Component{
            type: 5,
            custom_id: "LFGBOT_KICK_SELECT_" <> session_id,
            min_values: 1,
            max_values: 1,
            placeholder: "Player to kick"
          }
        ]
      )

    player_to_kick_id =
      case player_to_kick_id do
        id when is_binary(id) -> id
        id when is_integer(id) -> Snowflake.dump(id)
        _ -> "DISABLED"
      end

    submit_button =
      ActionRow.action_row(
        components: [
          Button.interaction_button(
            "Kick",
            "LFGBOT_KICK_SUBMIT_" <> session_id <> "_" <> player_to_kick_id,
            style: Nostrum.Constants.ButtonStyle.primary(),
            disabled: player_to_kick_id == "DISABLED",
            emoji: %{name: "🥾"}
          )
        ]
      )

    [select_menu, submit_button]
  end

  defp is_session_leader?(session, invoker_id) when is_integer(invoker_id) do
    is_session_leader?(session, Snowflake.dump(invoker_id))
  end

  defp is_session_leader?(session, invoker_id) when is_binary(invoker_id) do
    session.leader_user_id == invoker_id
  end
end
