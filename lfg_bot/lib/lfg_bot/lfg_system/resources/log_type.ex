defmodule LfgBot.LfgSystem.LogType do
  use Ash.Type.Enum, values: [:info, :warning, :error]
end
