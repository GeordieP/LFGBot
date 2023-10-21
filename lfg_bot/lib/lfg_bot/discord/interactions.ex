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

    :ok
  end
end
