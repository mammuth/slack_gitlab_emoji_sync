defmodule EmojiSync do
  @moduledoc """
  `EmojiSync` syncs custom emojis from Slack to GitLab.
  """

  require Logger

  alias EmojiSync.{GitLab, Slack}

  @doc """
  Runs the sync. Returns `:ok` or `{:error, reason}`.

  Both tokens are checked before any emoji is uploaded, so an invalid token
  fails fast instead of producing hundreds of rejected requests.
  """
  def sync do
    with :ok <- GitLab.verify_access(),
         {:ok, emojis} <- Slack.get_emojis(),
         {:ok, existing} <- GitLab.list_emoji_names() do
      {present, missing} = Enum.split_with(emojis, &MapSet.member?(existing, &1.name))

      missing
      |> Enum.map(&GitLab.create_emoji/1)
      |> summarize(length(present))
    end
  end

  defp summarize(results, already_present) do
    counts =
      Enum.frequencies_by(results, fn
        :ok -> :created
        :skipped -> :skipped
        {:error, _reason} -> :failed
      end)

    created = Map.get(counts, :created, 0)
    skipped = Map.get(counts, :skipped, 0) + already_present
    failed = Map.get(counts, :failed, 0)

    Logger.info("Sync finished: #{created} created, #{skipped} already existed, #{failed} failed")

    if failed > 0,
      do: {:error, "#{failed} emoji(s) could not be created in GitLab"},
      else: :ok
  end
end
