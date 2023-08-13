defmodule BdfrBrowser.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :author, :string
      add :body, :text
      add :score, :integer
      add :posted_at, :utc_datetime
      add :post_id, references(:posts)
      add :parent_id, references(:comments)
    end

    create index("comments", :post_id)
    create index("comments", :parent_id)
  end
end
