defmodule SymphonyElixir.GitHub.Client do
  @moduledoc """
  GitHub API client for detecting merged work.

  Checks whether an issue's branch (`symphony/SER-XX`) has been merged into
  the target branch (e.g. `cole`) — either via PR merge or direct worktree merge.
  Also falls back to GitHub search for merged PRs.
  """

  require Logger

  @github_api "https://api.github.com"
  @repos ["servicehelm/backend", "servicehelm/frontend", "servicehelm/mobile"]
  @target_branch "cole"

  @doc """
  Checks whether the work for a Linear issue has been merged.

  Looks for a `symphony/<IDENTIFIER>` branch in each repo and checks if
  the target branch fully contains it (compare status = "behind" or "identical").
  Also checks for merged PRs as a fallback.
  """
  @spec work_merged?(String.t()) :: boolean()
  def work_merged?(identifier) when is_binary(identifier) do
    case github_token() do
      nil ->
        Logger.debug("GitHub token not set; skipping merge detection")
        false

      token ->
        branch_merged?(identifier, token) || pr_merged?(identifier, token)
    end
  end

  defp branch_merged?(identifier, token) do
    branch = "symphony/#{identifier}"

    Enum.any?(@repos, fn repo ->
      case compare_branches(repo, @target_branch, branch, token) do
        {:ok, status} when status in ["behind", "identical"] ->
          Logger.info("Branch #{branch} is merged into #{@target_branch} in #{repo}")
          true

        {:ok, _status} ->
          false

        {:error, {:github_api_status, 404}} ->
          # Branch doesn't exist in this repo — not an error
          false

        {:error, reason} ->
          Logger.debug("Branch compare failed for #{repo} #{branch}: #{inspect(reason)}")
          false
      end
    end)
  end

  defp pr_merged?(identifier, token) do
    query = "is:pr is:merged #{identifier} org:servicehelm"

    case search_issues(query, token) do
      {:ok, %{"total_count" => count}} when is_integer(count) and count > 0 ->
        Logger.info("Merged PR found for #{identifier}: #{count} PR(s)")
        true

      _ ->
        false
    end
  end

  defp compare_branches(repo, base, head, token) do
    url = "#{@github_api}/repos/#{repo}/compare/#{base}...#{URI.encode(head, &URI.char_unreserved?/1)}"

    case github_get(url, token) do
      {:ok, %{"status" => status}} ->
        {:ok, status}

      error ->
        error
    end
  end

  defp search_issues(query, token) do
    url = "#{@github_api}/search/issues?q=#{URI.encode(query)}&per_page=1"
    github_get(url, token)
  end

  defp github_get(url, token) do
    headers = [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "symphony-orchestrator"}
    ]

    case Req.get(url, headers: headers, connect_options: [timeout: 10_000]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:github_api_status, status}}

      {:error, reason} ->
        {:error, {:github_api_request, reason}}
    end
  end

  defp github_token do
    case System.get_env("GITHUB_TOKEN") do
      nil -> nil
      "" -> nil
      token -> String.trim(token)
    end
  end
end
