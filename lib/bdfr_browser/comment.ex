defmodule BdfrBrowser.Comment do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias BdfrBrowser.{Post, Repo}

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "comments" do
    field :author, :string
    field :body, :string
    field :score, :integer
    field :posted_at, :utc_datetime

    belongs_to :post, Post
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
  end

  def fetch_children!(comment) do
    Repo.preload(comment, children: from(c in __MODULE__, order_by: [asc: c.posted_at])).children
  end

  def by_author(author) do
    from(c in __MODULE__,
      join: p in assoc(c, :post),
      join: s in assoc(p, :subreddit),
      select: %{
        body: c.body,
        children: [],
        posted_at: c.posted_at,
        subreddit: s.name,
        post_id: p.id,
        post_title: p.title,
        post_date: fragment("to_char(?, 'YYYY-MM')", p.posted_at)
      },
      where: c.author == ^author,
      order_by: [desc: c.posted_at],
      group_by: [c.id, p.id, s.name]
    )
  end

  def search(str) do
    search_str = "%#{str}%"

    from(c in __MODULE__,
      join: p in assoc(c, :post),
      join: s in assoc(p, :subreddit),
      select: %{
        author: c.author,
        body: c.body,
        children: [],
        posted_at: c.posted_at,
        subreddit: s.name,
        post_id: p.id,
        post_title: p.title,
        post_date: fragment("to_char(?, 'YYYY-MM')", p.posted_at)
      },
      where: ilike(c.body, ^search_str),
      order_by: [desc: c.posted_at],
      group_by: [c.id, p.id, s.name]
    )
  end
end
