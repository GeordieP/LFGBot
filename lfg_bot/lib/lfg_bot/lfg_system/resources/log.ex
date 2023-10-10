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
    attribute(:type, LogType)
    attribute(:data, :string)
    create_timestamp(:inserted_at)
  end

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:read, action: :read)
    define(:read_info, action: :read_info)
    define(:read_error, action: :read_error)
    define(:read_warning, action: :read_warning)
  end

  actions do
    defaults([:create, :read, :update, :destroy])

    read :read_info do
      prepare(build(limit: 15, sort: [:inserted_at]))
      filter(expr(type == :info))
    end

    read :read_error do
      prepare(build(limit: 15, sort: [:inserted_at]))
      filter(expr(type == :error))
    end

    read :read_warning do
      prepare(build(limit: 15, sort: [:inserted_at]))
      filter(expr(type == :warning))
    end
  end
end
