defmodule BdfrBrowser.Repo.Migrations.CreateSubreddits do
  use Ecto.Migration

  def change do
    create table(:subreddits, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :name, :string, size: 1024, unique: true
    end

    alter table("posts") do
      add :subreddit_id, references(:subreddits, type: :bigserial)
    end

    create index("posts", :subreddit_id)
    create index("subreddits", :name, unique: true)
  end
end
