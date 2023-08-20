defmodule BdfrBrowser.Repo.Migrations.AddChatTags do
  use Ecto.Migration

  def change do
    alter table("chats") do
      add :tags, {:array, :string}, default: []
    end
  end
end
