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

    # ID of the channel the registration message is in
    attribute :channel_id, :string do
      allow_nil?(false)
    end

    # ID of the registration message
    attribute(:message_id, :string)

    create_timestamp(:inserted_at)
    create_timestamp(:updated_at)
  end

  identities do
    identity(:unique_server, [:guild_id, :channel_id, :message_id])
  end

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:by_id, action: :by_id, args: [:id])

    define(:get_by_guild_and_channel,
      action: :get_by_guild_and_channel,
      args: [:guild_id, :channel_id]
    )

    define :update_message_id, action: :update_message_id, args: [:message_id]
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    read :by_id do
      argument :id, :string do
        allow_nil? false
      end

      filter(expr(id == ^arg(:id)))
      get? true
    end

    read :get_by_guild_and_channel do
      get?(true)

      argument :channel_id, :string do
        allow_nil?(false)
      end

      argument :guild_id, :string do
        allow_nil?(false)
      end

      filter(expr(guild_id == ^arg(:guild_id) and channel_id == ^arg(:channel_id)))
    end

    update :update_message_id do
      argument :message_id, :string do
        allow_nil? false
      end

      change set_attribute(:message_id, arg(:message_id))
    end
  end
end
