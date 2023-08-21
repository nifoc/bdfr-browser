defmodule BdfrBrowser.Repo.Migrations.AddChatMessageBookmarks do
  use Ecto.Migration

  def change do
    alter table("messages") do
      add :bookmark, :string
    end
  end
end
