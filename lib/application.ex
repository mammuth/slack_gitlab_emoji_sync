defmodule EmojiSync.Application do
  use Application

  def start(_type, _args) do
    EmojiSync.sync()
    {:ok, self()}
  end
end
