defmodule LfgBot.Repo.Migrations.AddRegisteredGuildChannel do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:registered_guild_channel, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :guild_id, :text, null: false
      add :intro_channel_id, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(
             :registered_guild_channel,
             [:guild_id, :intro_channel_id],
             name: "registered_guild_channel_unique_server_index"
           )
  end

  def down do
    drop_if_exists unique_index(
                     :registered_guild_channel,
                     [:guild_id, :intro_channel_id],
                     name: "registered_guild_channel_unique_server_index"
                   )

    drop table(:registered_guild_channel)
  end
end
