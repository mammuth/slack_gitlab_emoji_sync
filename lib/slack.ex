defmodule EmojiSync.Slack do
  require Logger

  @doc """
  Fetches the custom emojis of the Slack workspace.

  Doubles as the preflight check for the Slack token: an invalid or expired
  token makes Slack answer with `ok: false`, which is reported as an error
  instead of an empty emoji list.
  """
  def get_emojis do
    case Req.get(api_url(), headers: headers()) do
      {:ok, %{status: 200, body: %{"ok" => false, "error" => error}}} ->
        {:error, "Slack rejected the request: '#{error}'"}

      {:ok, %{status: 200, body: %{"emoji" => emoji}}} ->
        # Aliases point at another emoji ("alias:party_parrot") instead of an
        # image, so GitLab can only ever reject them.
        {aliases, emojis} =
          emoji
          |> Enum.map(fn {name, url} -> %{name: name, url: url} end)
          |> Enum.split_with(&alias?/1)

        Logger.info(
          "Successfully fetched #{Enum.count(emojis)} emojis from Slack (ignored #{Enum.count(aliases)} aliases)"
        )

        {:ok, emojis}

      {:ok, %{status: status, body: body}} ->
        {:error, "Unexpected response from Slack. status: #{status}. body: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request to Slack failed: #{inspect(reason)}"}
    end
  end

  defp alias?(%{url: url}), do: String.starts_with?(url, "alias:")

  defp api_url, do: "https://api.slack.com/api/emoji.list"

  defp headers do
    token = Application.fetch_env!(:emoji_sync, :slack_access_token)

    [
      {"Authorization", "Bearer #{token}"}
    ]
  end
end
