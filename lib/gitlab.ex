defmodule EmojiSync.GitLab do
  require Logger

  @doc """
  Preflight check: verifies that the GitLab token is still valid and that it
  can see the configured group. Returns `:ok` or `{:error, reason}` so a
  revoked token fails the sync immediately instead of after hundreds of
  rejected uploads.
  """
  def verify_access do
    case Req.post(url: api_url(), body: verify_payload(), headers: headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"group" => %{"id" => _}}}}} ->
        Logger.info("GitLab token is valid and can access group '#{group_path()}'")
        :ok

      {:ok, %{status: 200, body: %{"data" => %{"group" => nil}}}} ->
        {:error,
         "GitLab group '#{group_path()}' does not exist or is not visible to the access token"}

      {:ok, %{status: 401}} ->
        {:error, "GitLab rejected the access token (401) - it is invalid, expired or revoked"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Unexpected response from GitLab. status: #{status}. body: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request to GitLab failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Fetches the names of all custom emojis that already exist in the group.
  GitLab caps GraphQL pages at 100 nodes, so this follows the cursor until the
  last page. Returns `{:ok, MapSet.t()}` or `{:error, reason}`.
  """
  def list_emoji_names, do: list_emoji_names(nil, MapSet.new())

  defp list_emoji_names(cursor, names) do
    case Req.post(url: api_url(), body: list_payload(cursor), headers: headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"group" => %{"customEmoji" => emoji}}}}} ->
        %{"nodes" => nodes, "pageInfo" => page_info} = emoji
        names = Enum.into(nodes, names, & &1["name"])

        case page_info do
          %{"hasNextPage" => true, "endCursor" => next} ->
            list_emoji_names(next, names)

          _ ->
            Logger.info("Found #{MapSet.size(names)} existing emojis in GitLab")
            {:ok, names}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to list GitLab emojis. status: #{status}. body: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request to GitLab failed: #{inspect(reason)}"}
    end
  end

  # GitLab only accepts names matching /[a-z0-9_-]+/ with at most 36
  # characters, while Slack also allows longer names and non-ASCII letters.
  @max_name_length 36
  @umlauts %{"ä" => "ae", "ö" => "oe", "ü" => "ue", "ß" => "ss"}

  @doc """
  Maps a Slack emoji name to one GitLab accepts: umlauts are transliterated
  (`spätzle` -> `spaetzle`), other accents dropped (`café` -> `cafe`) and the
  result is cut to #{@max_name_length} characters.
  """
  def normalize_emoji_name(name) do
    name
    |> String.replace(Map.keys(@umlauts), &@umlauts[&1])
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.slice(0, @max_name_length)
  end

  # Rejections that every run will keep producing and that no retry can fix:
  # the emoji is already in the group, or its name collides with one of
  # GitLab's built-in emojis. Counting them as failures would turn every
  # scheduled sync red.
  @expected_rejections ["has already been taken", "is already being used for another emoji"]

  @doc """
  Creates a single custom emoji. Returns `:ok`, `:skipped` (nothing to do, see
  `@expected_rejections`) or `{:error, reason}`.
  """
  def create_emoji(%{name: name, url: url}) do
    case Req.post(url: api_url(), body: payload(name, url), headers: headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"createCustomEmoji" => %{"errors" => []}}}}} ->
        Logger.info("Created emoji '#{name}' successfully in GitLab")
        :ok

      {:ok, %{status: 200, body: %{"data" => %{"createCustomEmoji" => %{"errors" => errors}}}}} ->
        if expected_rejection?(errors) do
          Logger.info("Skipped emoji '#{name}': #{Enum.join(errors, ", ")}")
          :skipped
        else
          reason = Enum.join(errors, ", ")
          Logger.warning("Failed to create emoji '#{name}' in GitLab: #{reason}")
          {:error, reason}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.warning(
          "Failed to create emoji '#{name}' in GitLab. status: #{status}. body: #{inspect(body)}"
        )

        {:error, "status #{status}"}

      {:error, reason} ->
        Logger.error("Request to create emoji '#{name}' failed: #{inspect(reason)}")
        {:error, inspect(reason)}
    end
  end

  defp expected_rejection?(errors) do
    Enum.all?(errors, fn error ->
      Enum.any?(@expected_rejections, &String.contains?(error, &1))
    end)
  end

  defp api_url do
    host = Application.fetch_env!(:emoji_sync, :gitlab_hostname)
    "https://#{host}/api/graphql"
  end

  defp group_path, do: Application.fetch_env!(:emoji_sync, :gitlab_group_path)

  defp headers do
    token = Application.fetch_env!(:emoji_sync, :gitlab_access_token)
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"},
    ]
  end

  defp verify_payload do
    %{query: "query { group(fullPath: \"#{group_path()}\") { id } }"} |> Jason.encode!()
  end

  defp list_payload(cursor) do
    %{
      query: """
      query($path: ID!, $after: String) {
        group(fullPath: $path) {
          customEmoji(first: 100, after: $after) {
            nodes { name }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
      """,
      variables: %{path: group_path(), after: cursor}
    } |> Jason.encode!()
  end

  defp payload(name, url) do
    %{
      query: """
      mutation {
        createCustomEmoji(input: {groupPath: "#{group_path()}", name: "#{name}", url: "#{url}"}) {
          errors
        }
      }
      """ |> String.replace("\n", "")
    } |> Jason.encode!()
  end
end
