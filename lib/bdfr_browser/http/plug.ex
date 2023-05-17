defmodule BdfrBrowser.HTTP.Plug do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    tpl_params = [
      subreddits: list_folders(sort: :asc)
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/index.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit" do
    tpl_params = [
      subreddit: subreddit,
      dates: list_folders(paths: [subreddit])
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/subreddit.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date" do
    tpl_params = [
      subreddit: subreddit,
      date: date,
      posts: read_posts(paths: [subreddit, date], ext: ".json")
    ]

    tpl_file = Application.app_dir(:bdfr_browser, "priv/templates/http/subreddit_posts.eex")
    content = EEx.eval_file(tpl_file, tpl_params)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, content)
  end

  get "/r/:subreddit/:date/:post" do
    tpl_params = [
      subreddit: subreddit,
      date: date,
      post: read_post(post, paths: [subreddit, date]),
      media: post_media(post, paths: [subreddit, date]),
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

  match _ do
    send_resp(conn, 404, "Not Found")
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

    compact_posts =
      for post <- posts do
        {:ok, content} = [post_dir, post] |> Path.join() |> File.read!() |> Jason.decode()

        %{
          title: content["title"],
          author: content["author"],
          num_comments: content["num_comments"],
          created_utc: content["created_utc"],
          filename: Path.basename(post, ".json")
        }
      end

    Enum.sort_by(compact_posts, fn p -> p.created_utc end, sort)
  end

  defp read_post(post, args) do
    base_directory = Application.fetch_env!(:bdfr_browser, :base_directory)
    post_dir = Path.join([base_directory | Keyword.fetch!(args, :paths)])
    post_file = "#{post}.json"

    {:ok, content} = [post_dir, post_file] |> Path.join() |> File.read!() |> Jason.decode(keys: :atoms)
    content
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
    String.replace(full_path, "#{base_directory}/", "/media/")
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
