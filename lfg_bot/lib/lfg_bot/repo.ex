defmodule LfgBot.Repo do
  use AshPostgres.Repo, otp_app: :lfg_bot
#  use Ecto.Repo,
#    otp_app: :lfg_bot,
#    adapter: Ecto.Adapters.Postgres

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
