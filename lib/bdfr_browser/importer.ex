defmodule BdfrBrowser.Importer do
  require Logger

  use GenServer

  alias BdfrBrowser.{Chat, Comment, Message, Post, Repo, Subreddit}

  defmodule State do
    use TypedStruct

    typedstruct do
      field :fs_pid, pid
      field :post_changes, [Path.t()], default: []
      field :chat_changes, [Path.t()], default: []
    end
  end

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

  def chats do
    _ = Logger.info("Importing chats ...")

    result =
      for chat <- read_chats(directory_key: :chat_directory) do
        _ = Logger.info("Importing chat `#{chat["id"]}' ...")

        {:ok, chat_record} = import_chat(chat)
        message_records = for message <- chat["messages"], do: import_message(message, chat_record)

        {chat_record, List.flatten(message_records)}
      end

    List.flatten(result)
  end

  def background_import do
    GenServer.cast(__MODULE__, :background_import)
  end

  def background_import_changes do
    GenServer.cast(__MODULE__, :background_import_changes)
  end

  # Callbacks

  @impl true
  def init([]) do
    {:ok, %State{}, {:continue, :setup_fs}}
  end

  @impl true
  def handle_continue(:setup_fs, state) do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    chat_directory = Application.fetch_env!(:bdfr_browser, :chat_directory)

    {:ok, pid} = FileSystem.start_link(dirs: [base_directory, chat_directory])
    :ok = FileSystem.subscribe(pid)
    {:noreply, %State{state | fs_pid: pid}}
  end

  @impl true
  def handle_cast(:background_import, state) do
    _ = subreddits()
    _ = posts_and_comments()
    _ = chats()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:background_import_changes, state) do
    _ = subreddits()
    _ = changed_posts_and_comments(state.post_changes)
    _ = changed_chats(state.chat_changes)
    {:noreply, %State{state | post_changes: [], chat_changes: []}}
  end

  @impl true
  def handle_info({:file_event, pid, {path, events}}, %State{fs_pid: pid} = state) do
    _ = Logger.info("Events `#{inspect(events)}' on file `#{path}'")
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    chat_directory = Application.fetch_env!(:bdfr_browser, :chat_directory)
    ext = Path.extname(path)

    new_state =
      cond do
        String.contains?(path, chat_directory) and ext == ".json" ->
          %State{state | chat_changes: [path | state.chat_changes]}

        String.contains?(path, base_directory) and ext == ".json" ->
          %State{state | post_changes: [path | state.post_changes]}

        true ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:file_event, pid, :stop}, %State{fs_pid: pid} = state) do
    {:noreply, %State{state | fs_pid: nil}, {:continue, :setup_fs}}
  end

  # Helper

  defp list_folders(args) do
    paths = Keyword.get(args, :paths, [])
    extname = Keyword.get(args, :ext, "")
    sort = Keyword.get(args, :sort, :desc)
    directory_key = Keyword.get(args, :directory_key, :base_directory)
    base_directory = Application.fetch_env!(:bdfr_browser, directory_key)

    [base_directory | paths]
    |> Path.join()
    |> File.ls!()
    |> Enum.filter(fn s -> not String.starts_with?(s, ".") and Path.extname(s) == extname end)
    |> Enum.sort_by(&String.downcase/1, sort)
  end

  defp changed_posts_and_comments(posts) do
    result =
      for file_path <- posts do
        _ = Logger.info("Importing changed file `#{file_path}' ...")

        post = file_path |> File.read!() |> Jason.decode!()
        post = Map.put(post, "filename", Path.basename(file_path))

        ["r", subreddit, "comments", _, _] = String.split(post["permalink"], "/", trim: true)
        subreddit_record = Repo.get_by(Subreddit, name: subreddit)
        {:ok, post_record} = import_post(post, subreddit_record)
        comment_records = for comment <- post["comments"], do: import_comment(comment, post_record, nil)

        {post_record, List.flatten(comment_records)}
      end

    List.flatten(result)
  end

  defp changed_chats(chats) do
    result =
      for file_path <- chats do
        _ = Logger.info("Importing changed file `#{file_path}' ...")

        chat = file_path |> File.read!() |> Jason.decode!()
        chat = Map.put(chat, "filename", Path.basename(file_path))

        {:ok, chat_record} = import_chat(chat)
        message_records = for message <- chat["messages"], do: import_message(message, chat_record)

        {chat_record, List.flatten(message_records)}
      end

    List.flatten(result)
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

  defp read_chats(args) do
    directory_key = Keyword.get(args, :directory_key, :chat_directory)
    base_directory = Application.fetch_env!(:bdfr_browser, directory_key)

    new_chats =
      for chat <- list_folders([{:ext, ".json"} | args]) do
        file_path = Path.join([base_directory, chat])
        parsed = file_path |> File.read!() |> Jason.decode!()
        Map.put(parsed, "filename", chat)
      end

    old_chats =
      for chat <- list_folders([{:ext, ".json_lines"} | args]) do
        file_path = Path.join([base_directory, chat])

        messages =
          file_path
          |> File.stream!()
          |> Stream.map(&String.trim/1)
          |> Stream.map(fn line ->
            {:ok, [author, date, message]} = Jason.decode(line)
            formatted_date = date |> String.replace(" UTC", "Z") |> String.replace(" ", "T")

            %{
              "author" => author,
              "timestamp" => formatted_date,
              "content" => %{
                "Message" => message
              }
            }
          end)
          |> Enum.to_list()

        %{"id" => Path.basename(chat, ".json_lines"), "messages" => messages, "filename" => chat}
      end

    old_chats ++ new_chats
  end

  defp import_post(post, subreddit) when not is_nil(subreddit) do
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

  defp import_comment(comment, post, parent) when not is_nil(post) do
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

  defp import_chat(chat) do
    id = chat["id"]
    accounts = for message <- chat["messages"], uniq: true, do: message["author"]

    %Chat{
      id: id,
      accounts: accounts
    }
    |> Repo.insert(
      on_conflict: [set: [id: id]],
      conflict_target: :id
    )
  end

  defp import_message(message, chat) when not is_nil(chat) do
    id = :sha3_256 |> :crypto.hash([chat.id, message["timestamp"]]) |> Base.encode16(case: :lower)
    {:ok, posted_at, 0} = DateTime.from_iso8601(message["timestamp"])

    {:ok, message} =
      %Message{
        id: id,
        author: message["author"],
        message: message["content"]["Message"],
        posted_at: posted_at,
        chat: chat
      }
      |> Repo.insert(
        on_conflict: [set: [id: id]],
        conflict_target: :id
      )

    message
  end
end
