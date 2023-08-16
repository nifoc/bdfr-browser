defmodule BdfrBrowser.RenderUtils do
  def selftext(txt) do
    Earmark.as_html!(txt)
  end

  def comment(cmt) do
    Earmark.as_html!(cmt)
  end

  def message(msg) do
    img_replacement =
      "<p class=\"text-center\"><img src=\"/chat_media/\\1\" class=\"img-fluid\" loading=\"lazy\" /></p>"

    msg
    |> maybe_insert_image(img_replacement)
    |> String.replace(~r/https:\/\/i\.redd\.it\/(.+)/, img_replacement)
    |> Earmark.as_html!()
  end

  # Helper

  defp maybe_insert_image(<<"mxc://reddit.com/", filename::binary>> = msg, replacement) do
    chat_directory = Application.fetch_env!(:bdfr_browser, :chat_directory)
    img_directory = Path.join([chat_directory, "images"])
    imgs = Path.wildcard("#{img_directory}/#{filename}.*")

    if Enum.empty?(imgs) do
      msg
    else
      img = hd(imgs)
      String.replace(replacement, "\\1", Path.basename(img))
    end
  end

  defp maybe_insert_image(msg, _replacement), do: msg
end
