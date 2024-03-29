defmodule BdfrBrowser.Subreddit do
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]

  alias BdfrBrowser.Post

  schema "subreddits" do
    field(:name, :string)

    has_many(:posts, Post)
  end

  def names do
    from(s in __MODULE__, select: s.name, order_by: [asc: fragment("lower(?)", s.name)])
  end

  def names_without(hidden) do
    from(s in __MODULE__, select: s.name, where: s.name not in ^hidden, order_by: [asc: fragment("lower(?)", s.name)])
  end
end
