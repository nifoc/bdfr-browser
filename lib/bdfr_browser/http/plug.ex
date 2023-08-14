defmodule BdfrBrowser.HTTP.Plug do
  use Plug.Router

  alias BdfrBrowser.{Repo, Post, Subreddit}

  plug :match
  plug :dispatch

  get "/" do
    tpl_params = [
      subreddits: Subreddit.names() |> Repo.all()
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/index.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit" do
    subreddit_record = Repo.get_by(Subreddit, name: subreddit)

    tpl_params = [
      subreddit: subreddit,
      dates: subreddit_record |> Post.date_listing() |> Repo.all()
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/subreddit.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date" do
    subreddit_record = Repo.get_by(Subreddit, name: subreddit)

    tpl_params = [
      subreddit: subreddit,
      date: date,
      posts: subreddit_record |> Post.during_month(date) |> Repo.all()
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/subreddit_posts.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date/:id" do
    post_record = Post |> Repo.get(id) |> Repo.preload(comments: :children)

    tpl_params = [
      subreddit: subreddit,
      date: date,
      post: post_record,
      media: post_media(post_record.filename, paths: [subreddit, date]),
      comment_template: Application.app_dir(:bdfr_browser, "priv/templates/http/_comment.eex")
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/post.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/media/*path" do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    joined_path = Path.join(path)
    {:ok, media} = [base_directory, joined_path] |> Path.join() |> File.read()

    conn
    |> put_resp_header("content-type", mime_from_ext(joined_path))
    |> send_resp(200, media)
  end

  post "/_import" do
    :ok = BdfrBrowser.Importer.background_import()
    send_resp(conn, 200, "IMPORTING")
  end

  get "/_ping" do
    send_resp(conn, 200, "PONG")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  # Helper

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
    end
  end
end
