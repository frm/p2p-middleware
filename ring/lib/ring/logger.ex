defmodule Ring.Logger do
  require Logger

  def info(str) do
    Logger.info fn -> str end
  end
end
