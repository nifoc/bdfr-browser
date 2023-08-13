defmodule BdfrBrowser.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, size: 1024
      add :selftext, :text
      add :url, :string, size: 2048
      add :permalink, :string, size: 2048
      add :author, :string
      add :upvote_ratio, :float
      add :posted_at, :utc_datetime
    end
  end
end
