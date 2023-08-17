defmodule BdfrBrowser.HTTP.Plug do
  use Plug.Router

  alias BdfrBrowser.{Chat, Comment, Importer, Message, Repo, Post, Subreddit}

  plug :match
  plug :dispatch

  get "/" do
    config_file = Application.fetch_env!(:bdfr_browser, :config_file)
    hidden_subreddits = config_file["hidden_subreddits"]

    tpl_args = [subreddits: Subreddit.names_without(hidden_subreddits) |> Repo.all()]
    content = render_template("index", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit" do
    subreddit_record = Repo.get_by(Subreddit, name: subreddit)

    tpl_args = [
      subreddit: subreddit,
      dates: subreddit_record |> Post.date_listing() |> Repo.all()
    ]

    content = render_template("subreddit", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date" do
    subreddit_record = Repo.get_by(Subreddit, name: subreddit)

    tpl_args = [
      subreddit: subreddit,
      date: date,
      posts: subreddit_record |> Post.during_month(date) |> Repo.all()
    ]

    content = render_template("subreddit_posts", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date/:id" do
    post_record = id |> Post.get_full() |> Repo.one()

    tpl_args = [
      subreddit: subreddit,
      date: date,
      post: post_record,
      media: post_media(post_record.filename, paths: [subreddit, date]),
      comment_template: Application.app_dir(:bdfr_browser, "priv/templates/http/_comment.eex")
    ]

    content = render_template("post", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/chats" do
    tpl_args = [chats: Chat.listing() |> Repo.all()]
    content = render_template("chats", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/chats/:id" do
    chat_record = Repo.get(Chat, id)

    tpl_args = [
      chat: chat_record,
      messages: chat_record |> Message.listing() |> Repo.all()
    ]

    content = render_template("chat", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/user/:name" do
    tpl_args = [
      name: name,
      posts: name |> Post.by_author() |> Repo.all(),
      comments: name |> Comment.by_author() |> Repo.all(),
      chats: name |> Chat.by_author() |> Repo.all()
    ]

    content = render_template("user", tpl_args)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/static/*path" do
    file_path = Application.app_dir(:bdfr_browser, Path.join("priv/static", path))

    if File.exists?(file_path) do
      {:ok, file} = File.read(file_path)

      conn
      |> put_resp_header("content-type", mime_from_ext(file_path))
      |> send_resp(200, file)
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  get "/media/*path" do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    joined_path = Path.join(path)
    file_path = Path.join([base_directory, joined_path])

    if File.exists?(file_path) do
      {:ok, media} = File.read(file_path)

      conn
      |> put_resp_header("content-type", mime_from_ext(file_path))
      |> send_resp(200, media)
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  get "/chat_media/*path" do
    chat_directory = Application.fetch_env!(:bdfr_browser, :chat_directory)
    joined_path = Path.join(path)
    file_path = Path.join([chat_directory, "images", joined_path])

    if File.exists?(file_path) do
      {:ok, media} = File.read(file_path)

      conn
      |> put_resp_header("content-type", mime_from_ext(file_path))
      |> send_resp(200, media)
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  post "/_import" do
    :ok = Importer.background_import()
    send_resp(conn, 200, "IMPORTING")
  end

  post "/_import_changes" do
    :ok = Importer.background_import_changes()
    send_resp(conn, 200, "IMPORTING CHANGES")
  end

  post "/_cleanup" do
    _ = Importer.cleanup_messages()
    send_resp(conn, 200, "CLEANED UP")
  end

  get "/_ping" do
    send_resp(conn, 200, "PONG")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  # Helper

  defp render_template(name, args) do
    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/application.eex")
    embedded_tpl = Application.app_dir(:bdfr_browser, "priv/templates/http/#{name}.eex")
    EEx.eval_file(tpl_file, embedded_template: embedded_tpl, embedded_args: args)
  end

  defp post_media(post, args) do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    post_dir = Path.join([base_directory | Keyword.fetch!(args, :paths)])
    post_img = "#{post}*.{jpg,JPG,jpeg,JPEG,png,PNG,gif,GIF}"
    post_vid = "#{post}*.{mp4,MP4}"

    %{
      images: [post_dir, post_img] |> Path.join() |> Path.wildcard() |> Enum.map(&media_path/1),
      videos: [post_dir, post_vid] |> Path.join() |> Path.wildcard() |> Enum.map(&media_path/1)
    }
  end

  defp media_path(full_path) do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)

    full_path
    |> String.replace("#{base_directory}/", "/media/")
    |> String.split("/")
    |> Enum.map(fn p -> URI.encode(p, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end

  defp mime_from_ext(path) do
    normalized_path = String.downcase(path)

    case Path.extname(normalized_path) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".mp4" -> "video/mp4"
      ".js" -> "text/javascript"
      ".css" -> "text/css"
    end
  end
end
