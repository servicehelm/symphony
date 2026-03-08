defmodule SymphonyElixir.CommentPoller do
  @moduledoc """
  Polls Linear for new human comments on an active issue and injects them
  into the running Codex turn via `turn/steer`.

  Spawned by `AgentRunner` alongside each turn. Sends `{:steer, message, id}`
  to the port-owning process when a new comment is detected.
  """

  require Logger
  alias SymphonyElixir.Tracker

  @poll_interval_ms 15_000

  @doc """
  Starts polling for new comments on the given issue.

  - `issue_id` — the Linear issue ID
  - `turn_owner_pid` — the process running the Codex receive loop (gets `:steer` messages)
  - `opts` — optional overrides:
    - `:poll_interval_ms` — how often to check (default #{@poll_interval_ms}ms)
    - `:comment_fetcher` — function for fetching comments (default `Tracker.fetch_comments/1`)

  Returns `{:ok, pid}`. The poller stops automatically when the parent process dies
  (it is linked).
  """
  @spec start_link(String.t(), pid(), keyword()) :: {:ok, pid()}
  def start_link(issue_id, turn_owner_pid, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    comment_fetcher = Keyword.get(opts, :comment_fetcher, &Tracker.fetch_comments/1)

    pid =
      spawn_link(fn ->
        # Snapshot existing comment IDs so we only inject new ones
        known_ids = fetch_known_comment_ids(issue_id, comment_fetcher)
        poll_loop(issue_id, turn_owner_pid, known_ids, 0, poll_interval, comment_fetcher)
      end)

    {:ok, pid}
  end

  defp fetch_known_comment_ids(issue_id, comment_fetcher) do
    case comment_fetcher.(issue_id) do
      {:ok, comments} ->
        comments
        |> Enum.map(& &1.id)
        |> MapSet.new()

      {:error, reason} ->
        Logger.warning("CommentPoller: failed to fetch initial comments for #{issue_id}: #{inspect(reason)}")
        MapSet.new()
    end
  end

  defp poll_loop(issue_id, turn_owner_pid, known_ids, steer_counter, interval, comment_fetcher) do
    Process.sleep(interval)

    unless Process.alive?(turn_owner_pid) do
      Logger.debug("CommentPoller: turn owner dead, stopping for #{issue_id}")
      exit(:normal)
    end

    case comment_fetcher.(issue_id) do
      {:ok, comments} ->
        Logger.debug("CommentPoller: fetched #{length(comments)} comments for #{issue_id}, #{MapSet.size(known_ids)} known")
        # Find new comments that weren't made by the agent itself.
        # We can't use is_me because the user's personal API key owns both
        # human UI comments and agent API comments. Instead, filter out
        # comments that look like agent workpad updates.
        new_comments =
          comments
          |> Enum.reject(fn c -> MapSet.member?(known_ids, c.id) end)
          |> Enum.reject(fn c -> agent_comment?(c.body) end)
          |> Enum.sort_by(& &1.created_at)

        {updated_known, updated_counter} =
          Enum.reduce(new_comments, {known_ids, steer_counter}, fn comment, {ids, counter} ->
            steer_message = format_steer_message(comment)
            Logger.info("CommentPoller: injecting comment from #{comment.user_name} on #{issue_id}")
            send(turn_owner_pid, {:steer, steer_message, counter})
            {MapSet.put(ids, comment.id), counter + 1}
          end)

        poll_loop(issue_id, turn_owner_pid, updated_known, updated_counter, interval, comment_fetcher)

      {:error, reason} ->
        Logger.warning("CommentPoller: failed to fetch comments for #{issue_id}: #{inspect(reason)}")
        poll_loop(issue_id, turn_owner_pid, known_ids, steer_counter, interval, comment_fetcher)
    end
  end

  # Agent-generated comments contain workpad markers or status prefixes.
  # Human comments from the Linear UI won't have these.
  defp agent_comment?(nil), do: false

  defp agent_comment?(body) when is_binary(body) do
    String.contains?(body, "## Codex Workpad") or
      String.contains?(body, "symphony-agent:") or
      String.starts_with?(String.trim(body), "QA Review:")
  end

  defp format_steer_message(comment) do
    """
    [Live comment from #{comment.user_name || "team member"} on Linear]:

    #{comment.body}

    ---
    Acknowledge this comment and adjust your approach if needed. If the comment contains new instructions, follow them. If it asks a question, answer it in your workpad.
    """
  end
end
