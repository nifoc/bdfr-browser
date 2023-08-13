defmodule BdfrBrowser.Comment do
  use Ecto.Schema

  alias BdfrBrowser.Post

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
end
