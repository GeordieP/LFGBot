defmodule LfgBot.Discord.CommandHandlers do
  require Logger
  import Bitwise

  alias Nostrum.Api, as: DiscordAPI
  alias LfgBot.Discord.Consumer
  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.{Session, RegisteredGuildChannel}
  alias Nostrum.Struct.{Interaction, User, Message, Embed}
  alias Nostrum.Struct.Component.{ActionRow, Button}
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{ApplicationCommandInteractionData, Interaction}
  alias LfgBot.Discord.{InteractionHandlers, CommandHandlers, MessageHandlers}

  # INFO: @command_name defined as a module attribute so it can be pattern matched

  @command_name_init "init"
  @command_details_init %{
    name: @command_name_init,
    description: "Set up LFG Bot in the current channel"
  }

  def install_global_commands() do
    global_commands = [
      @command_details_init
    ]

    {:ok, _commands} = DiscordAPI.bulk_overwrite_global_application_commands(global_commands)
    {:ok}
  end

  def install_guild_commands(_guilds) do
    {:not_implemented}
  end

  def delete_all_global_commands() do
    {:ok, commands} = DiscordAPI.get_global_application_commands()

    for %{id: command_id} <- commands do
      DiscordAPI.delete_global_application_command(command_id)
    end

    {:ok}
  end

  def delete_all_guild_commands(guild_id) do
    {:ok, commands} = DiscordAPI.get_guild_application_commands(guild_id)

    for %{id: command_id} <- commands do
      DiscordAPI.delete_guild_application_command(guild_id, command_id)
    end

    {:ok}
  end

  # -----

  def handle_command(
        %Interaction{
          channel_id: channel_id,
          guild_id: guild_id,
          user: %{id: invoker_user_id, username: invoker_user_name},
          data: %ApplicationCommandInteractionData{name: @command_name_init}
        } = interaction
      ) do
    Logger.debug(
      "[DISCORD EVENT] [REGISTER CHANNEL] invoker: #{invoker_user_name} #{invoker_user_id} | guild id: #{guild_id}"
    )

    {:ok} = InteractionHandlers.register_channel(interaction, guild_id, channel_id)
  end
end
