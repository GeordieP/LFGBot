defmodule LfgBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      LfgBotWeb.Telemetry,
      # Start the Ecto repository
      LfgBot.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: LfgBot.PubSub},
      # Start Finch
      {Finch, name: LfgBot.Finch},
      # Start the Endpoint (http/https)
      LfgBotWeb.Endpoint

      # Start a worker by calling: LfgBot.Worker.start_link(arg)
      # {LfgBot.Worker, arg}
    ]

    children =
      if Application.get_env(:lfg_bot, :should_start_nostrum) do
        children ++ [LfgBot.Discord.Supervisor]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LfgBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LfgBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
