defmodule LfgBot.LfgSystem.Log do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.LogType

  postgres do
    table("logs")
    repo(LfgBot.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute :type, LogType
    attribute :data, :string
  end

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end
