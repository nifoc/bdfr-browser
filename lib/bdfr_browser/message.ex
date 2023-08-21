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
    field :bookmark, :string

    belongs_to :chat, Chat
  end

  def listing(chat) do
    from(m in __MODULE__,
      where: m.chat_id == ^chat.id,
      order_by: [asc: m.posted_at]
    )
  end

  def images do
    from(m in __MODULE__,
      where: like(m.message, "mxc://%") or like(m.message, "https://i.redd.it/%"),
      order_by: [asc: m.posted_at]
    )
  end

  def potential_duplicates(other_m) do
    from(m in __MODULE__,
      where: m.id != ^other_m.id and m.chat_id == ^other_m.chat_id and m.posted_at == ^other_m.posted_at,
      order_by: [asc: m.posted_at]
    )
  end
end
