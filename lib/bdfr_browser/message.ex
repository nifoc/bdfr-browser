defmodule BdfrBrowser.Message do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias BdfrBrowser.Chat

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "messages" do
    field :author, :string
    field :message, :string
    field :posted_at, :utc_datetime

    belongs_to :chat, Chat
  end

  def listing(chat) do
    from(m in __MODULE__,
      where: m.chat_id == ^chat.id,
      order_by: [asc: m.posted_at]
    )
  end
end
