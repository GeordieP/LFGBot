defmodule LfgBot.Repo do
  use Ecto.Repo,
    otp_app: :lfg_bot,
    adapter: Ecto.Adapters.Postgres
end
