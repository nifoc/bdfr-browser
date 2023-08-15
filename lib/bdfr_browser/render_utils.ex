defmodule BdfrBrowser.RenderUtils do
  def message(msg) do
    img_replacement = "<img src=\"/chat_media/\\1\" style=\"max-width: 500px;\" alt=\"Image\" />"

    msg
    |> String.replace(~r/https:\/\/i\.redd\.it\/(.+)/, img_replacement)
    |> Earmark.as_html!()
  end
end
