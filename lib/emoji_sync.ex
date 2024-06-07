defmodule EmojiSync do
  @moduledoc """
  `EmojiSync` syncs custom emojis from Slack to GitLab.
  """

  alias EmojiSync.{GitLab, Slack}

  def sync do
    Slack.get_emojis()
    |> Enum.each(&GitLab.create_emoji/1)
  end

end
