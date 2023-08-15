defmodule BdfrBrowser.Post do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias BdfrBrowser.{Comment, Subreddit}

  @primary_key {:id, :string, autogenerate: false}

  schema "posts" do
    field :title, :string
    field :selftext, :string
    field :url, :string
    field :permalink, :string
    field :author, :string
    field :upvote_ratio, :float
    field :posted_at, :utc_datetime
    field :filename, :string

    belongs_to :subreddit, Subreddit
    has_many :comments, Comment
  end

  def date_listing(subreddit) do
    from(p in __MODULE__,
      select: fragment("to_char(?, 'YYYY-MM')", p.posted_at),
      where: p.subreddit_id == ^subreddit.id,
      distinct: true,
      order_by: [desc: fragment("to_char(?, 'YYYY-MM')", p.posted_at)]
    )
  end

  def during_month(subreddit, month_str) do
    {:ok, d} = Date.from_iso8601("#{month_str}-01")
    during_range(subreddit, Date.beginning_of_month(d), Date.end_of_month(d))
  end

  def during_range(subreddit, start_date, end_date) do
    from(p in __MODULE__,
      join: c in assoc(p, :comments),
      select: %{id: p.id, title: p.title, author: p.author, posted_at: p.posted_at, num_comments: count(c.id)},
      where:
        p.subreddit_id == ^subreddit.id and type(p.posted_at, :date) >= ^start_date and
          type(p.posted_at, :date) <= ^end_date,
      order_by: [desc: p.posted_at],
      group_by: p.id
    )
  end

  def by_author(author) do
    from(p in __MODULE__,
      join: c in assoc(p, :comments),
      join: s in assoc(p, :subreddit),
      select: %{
        id: p.id,
        title: p.title,
        posted_at: p.posted_at,
        num_comments: count(c.id),
        subreddit: s.name,
        date: fragment("to_char(?, 'YYYY-MM')", p.posted_at)
      },
      where: p.author == ^author,
      order_by: [desc: p.posted_at],
      group_by: [p.id, s.name]
    )
  end
end
