defmodule BdfrBrowser.Importer do
  require Logger

  use GenServer

  alias BdfrBrowser.{Comment, Post, Repo, Subreddit}

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def subreddits do
    _ = Logger.info("Importing subreddits ...")

    folders = list_folders(sort: :asc)

    for folder <- folders do
      %Subreddit{name: folder}
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: :name
      )
    end
  end

  def posts_and_comments do
    _ = Logger.info("Importing posts and comments ...")

    result =
      for subreddit <- list_folders(sort: :asc) do
        _ = Logger.info("Importing entries from `#{subreddit}' ...")

        subreddit_record = Repo.get_by(Subreddit, name: subreddit)

        for date <- list_folders(paths: [subreddit]) do
          _ = Logger.debug("Importing entries from `#{subreddit}' on `#{date}' ...")

          for post <- read_posts(paths: [subreddit, date], ext: ".json") do
            _ = Logger.debug("Importing `#{post["id"]}' from `#{subreddit}' ...")

            {:ok, post_record} = import_post(post, subreddit_record)
            comment_records = for comment <- post["comments"], do: import_comment(comment, post_record, nil)

            {post_record, List.flatten(comment_records)}
          end
        end
      end

    List.flatten(result)
  end

  def background_import do
    GenServer.cast(__MODULE__, :background_import)
  end

  # Callbacks

  @impl true
  def init([]) do
    {:ok, nil}
  end

  @impl true
  def handle_cast(:background_import, state) do
    _ = subreddits()
    _ = posts_and_comments()
    {:noreply, state}
  end

  # Helper

  defp list_folders(args) do
    paths = Keyword.get(args, :paths, [])
    extname = Keyword.get(args, :ext, "")
    sort = Keyword.get(args, :sort, :desc)
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)

    [base_directory | paths]
    |> Path.join()
    |> File.ls!()
    |> Enum.filter(fn s -> not String.starts_with?(s, ".") and Path.extname(s) == extname end)
    |> Enum.sort_by(&String.downcase/1, sort)
  end

  defp read_posts(args) do
    posts = list_folders(args)
    sort = Keyword.get(args, :sort, :desc)

    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    post_dir = Path.join([base_directory | Keyword.fetch!(args, :paths)])

    parsed_posts =
      for post <- posts do
        file_path = Path.join([post_dir, post])
        parsed = file_path |> File.read!() |> Jason.decode!()
        Map.put(parsed, "filename", post)
      end

    Enum.sort_by(parsed_posts, fn p -> p["created_utc"] end, sort)
  end

  defp import_post(post, subreddit) do
    id = post["id"]

    %Post{
      id: id,
      title: post["title"],
      selftext: post["selftext"],
      url: post["url"],
      permalink: post["permalink"],
      author: post["author"],
      upvote_ratio: post["upvote_ratio"],
      posted_at: DateTime.from_unix!(trunc(post["created_utc"])),
      filename: Path.basename(post["filename"], ".json"),
      subreddit: subreddit
    }
    |> Repo.insert(
      on_conflict: [set: [id: id]],
      conflict_target: :id
    )
  end

  defp import_comment(comment, post, parent) do
    id = comment["id"]

    {:ok, parent} =
      %Comment{
        id: id,
        author: comment["author"],
        body: comment["body"],
        score: comment["score"],
        posted_at: DateTime.from_unix!(trunc(comment["created_utc"])),
        post: post,
        parent: parent
      }
      |> Repo.insert(
        on_conflict: [set: [id: id]],
        conflict_target: :id
      )

    children = for child <- comment["replies"], do: import_comment(child, post, parent)

    [parent] ++ children
  end
end
