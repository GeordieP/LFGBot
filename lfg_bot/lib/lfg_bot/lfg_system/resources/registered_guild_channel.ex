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

    # ID of the introduction/help message
    attribute(:intro_message_id, :string) do
      allow_nil?(false)
    end

    create_timestamp(:inserted_at)
    create_timestamp(:updated_at)
  end

  identities do
    identity(:unique_server, [:guild_id, :intro_channel_id, :intro_message_id])
  end

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:read, action: :read)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end
