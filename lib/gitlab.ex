defmodule EmojiSync.GitLab do
  require Logger

  @doc """
  Preflight check: verifies that the GitLab token is valid, that it can see the
  configured group and that it is actually allowed to create custom emojis
  there. Returns `:ok` or `{:error, reason}`, so a token that is expired or
  too weak fails the sync immediately instead of after hundreds of rejected
  uploads.

  Reading the group is not enough: a Guest/Reporter token can read a group but
  not upload emojis to it, so the same ability the mutation authorizes
  (`createCustomEmoji`) is checked up front.
  """
  def verify_access do
    case Req.post(url: api_url(), body: verify_payload(), headers: headers()) do
      {:ok,
       %{
         status: 200,
         body: %{"data" => %{"group" => %{"userPermissions" => %{"createCustomEmoji" => true}}}}
       }} ->
        Logger.info("GitLab token may create custom emojis in group '#{group_path()}'")
        :ok

      {:ok,
       %{
         status: 200,
         body: %{"data" => %{"group" => %{"userPermissions" => %{"createCustomEmoji" => false}}}}
       }} ->
        {:error,
         "The GitLab token can read group '#{group_path()}' but may not create custom emojis " <>
           "there. It needs at least the Developer role - a Guest or Reporter token passes every " <>
           "read but has every upload rejected"}

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

  # Rejections that every run will keep producing and that no retry can fix:
  # the emoji is already in the group, or its name collides with one of
  # GitLab's built-in emojis. Counting them as failures would turn every
  # scheduled sync red.
  @expected_rejections ["has already been taken", "is already being used for another emoji"]

  @doc """
  Creates a single custom emoji. Returns `:ok`, `:skipped` (nothing to do, see
  `@expected_rejections`), `{:error, reason}` for a problem with this one emoji
  or `{:fatal, reason}` when GitLab refuses in a way that will affect every
  remaining emoji too.
  """
  def create_emoji(%{name: name, url: url}) do
    case Req.post(url: api_url(), body: payload(name, url), headers: headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"createCustomEmoji" => %{"errors" => []}}}}} ->
        Logger.info("Created emoji '#{name}' successfully in GitLab")
        :ok

      # A top-level GraphQL error means the mutation was rejected outright
      # (authorization, token scope, ...) rather than the emoji being invalid,
      # so every following emoji would be rejected the same way.
      {:ok, %{status: 200, body: %{"errors" => [%{"message" => message} | _]}}} ->
        {:fatal,
         "GitLab refused the createCustomEmoji mutation: #{message}. The token needs the 'api' " <>
           "scope and at least the Developer role on group '#{group_path()}'"}

      {:ok, %{status: 401}} ->
        {:fatal, "GitLab rejected the access token (401) mid-run - it may have been revoked"}

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
    %{
      query:
        "query { group(fullPath: \"#{group_path()}\") { userPermissions { createCustomEmoji } } }"
    }
    |> Jason.encode!()
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
