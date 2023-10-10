defmodule LfgBot.LfgSystem.RegisteredGuildChannel do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  alias LfgBot.LfgSystem

  postgres do
    table("registered_guild_channel")
    repo(LfgBot.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # ID of the guild the control channel is in
    attribute :guild_id, :string do
      allow_nil?(false)
    end

    # ID of the channel the introduction/help message is in
    attribute :intro_channel_id, :string do
      allow_nil?(false)
    end

    create_timestamp(:inserted_at)
    create_timestamp(:updated_at)
  end

  identities do
    identity(:unique_server, [:guild_id, :intro_channel_id])
  end

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:read, action: :read)

    define(:get_by_guild_and_channel,
      action: :get_by_guild_and_channel,
      args: [:guild_id, :intro_channel_id]
    )
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    read :get_by_guild_and_channel do
      get?(true)

      argument :intro_channel_id, :string do
        allow_nil?(false)
      end

      argument :guild_id, :string do
        allow_nil?(false)
      end

      filter(expr(guild_id == ^arg(:guild_id) and intro_channel_id == ^arg(:intro_channel_id)))
    end
  end
end
