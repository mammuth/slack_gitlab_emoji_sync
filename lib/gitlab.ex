defmodule EmojiSync.GitLab do
  require Logger

  def create_emoji(%{name: name, url: url}) do
    case Req.post(url: api_url(), body: payload(name, url), headers: headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"createCustomEmoji" => %{"errors" => []}}}}} ->
        Logger.info("Created emoji '#{name}' successfully in GitLab")

      {:ok, %{status: 200, body: %{"data" => %{"createCustomEmoji" => %{"errors" => errors}}}}} ->
        Logger.warning("Failed to create emoji '#{name}' in GitLab: #{Enum.join(errors, ", ")}")

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Failed to create emoji '#{name}' in GitLab. status: #{status}. Body:")
        IO.inspect(body)

      {:error, reason} ->
        Logger.error("Request to create emoji '#{name}' failed. Reason:\n")
        IO.inspect(reason)

      _ ->
        Logger.error("Unexpected error creating emoji in GitLab")
    end
  end

  defp api_url do
    host = Application.fetch_env!(:emoji_sync, :gitlab_hostname)
    "https://#{host}/api/graphql"
  end

  defp headers do
    token = Application.fetch_env!(:emoji_sync, :gitlab_access_token)
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"},
    ]
  end

  defp payload(name, url) do
    group_path = Application.fetch_env!(:emoji_sync, :gitlab_group_path)
    %{
      query: """
      mutation {
        createCustomEmoji(input: {groupPath: "#{group_path}", name: "#{name}", url: "#{url}"}) {
          errors
        }
      }
      """ |> String.replace("\n", "")
    } |> Jason.encode!()
  end
end
