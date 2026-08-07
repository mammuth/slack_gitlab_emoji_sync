defmodule EmojiSync.Application do
  use Application

  require Logger

  def start(_type, _args) do
    case EmojiSync.sync() do
      :ok ->
        {:ok, self()}

      {:error, reason} ->
        Logger.error("Emoji sync failed: #{reason}")
        # Flush before halting, otherwise the log lines above are lost.
        Logger.flush()
        System.halt(1)
    end
  end
end
