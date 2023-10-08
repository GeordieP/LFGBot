defmodule LfgBot.Repo.Migrations.CreateSessions do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:sessions, primary_key: false) do
      add :state, :text, null: false, default: "waiting"
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :error, :text
      add :error_state, :text
      add :player_reserve, {:array, :map}
      add :teams, {:array, :map}
    end
  end

  def down do
    drop table(:sessions)
  end
end