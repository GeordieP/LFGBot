defmodule LfgBot.LfgSystem do
  use Ash.Api

  resources do
    registry LfgBot.LfgSystem.Registry
  end
end
