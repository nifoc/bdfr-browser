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
    |> String.replace(~r/https:\/\/i\.redd\.it\/(.+)/, img_replacement)
    |> Earmark.as_html!()
  end
end
