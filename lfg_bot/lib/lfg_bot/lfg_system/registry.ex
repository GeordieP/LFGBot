defmodule LfgBot.LfgSystem.Registry do
  use Ash.Registry,
    extensions: [
      Ash.Registry.ResourceValidations
    ]

  entries do
    entry LfgBot.LfgSystem.Session
    entry LfgBot.LfgSystem.Log
  end
end
