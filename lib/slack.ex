defmodule EmojiSync.Slack do
  require Logger

  def get_emojis do
    case Req.get(api_url(), headers: headers()) do
      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        Logger.error("Error fetching emojis from Slack: '#{error}'")
        []

      {:ok, %{status: 200, body: %{"emoji" => emoji}}} ->
        emojis = Enum.map(emoji, fn {name, url} -> %{name: name, url: url} end) |> Enum.to_list()
        Logger.info("Successfully fetched #{Enum.count(emojis)} emojis from Slack")
        emojis

      _ ->
        Logger.error("Unexpected error fetching emojis from Slack")
        []
    end
  end

  defp api_url do
    "https://api.slack.com/api/emoji.list"
  end

  defp headers do
    token = Application.fetch_env!(:emoji_sync, :slack_access_token)

    [
      {"Authorization", "Bearer #{token}"}
    ]
  end
end
