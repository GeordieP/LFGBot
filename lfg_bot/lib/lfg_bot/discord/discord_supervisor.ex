defmodule LfgBot.Discord.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_props) do
    children = [LfgBot.Discord.Consumer]
    _table = :ets.new(:lfg_bot_table, [:named_table, :set, :public])
    Supervisor.init(children, strategy: :one_for_one)
  end
end
