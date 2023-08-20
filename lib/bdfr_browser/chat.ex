defmodule BdfrBrowser.Chat do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2, where: 3]

  alias BdfrBrowser.Message

  @primary_key {:id, :string, autogenerate: false}

  schema "chats" do
    field :accounts, {:array, :string}
    field :tags, {:array, :string}, default: []

    has_many :messages, Message
  end

  def listing do
    from(c in __MODULE__,
      left_join: m in assoc(c, :messages),
      select: %{
        id: c.id,
        accounts: c.accounts,
        num_messages: count(m.id),
        latest_message: max(m.posted_at),
        tags: c.tags
      },
      order_by: [desc: max(m.posted_at)],
      group_by: c.id
    )
  end

  def by_author(author) do
    listing() |> where([c], ^author in c.accounts)
  end
end
