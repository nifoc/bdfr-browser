defmodule BdfrBrowser.Repo.Migrations.AddPostFilename do
  use Ecto.Migration

  def change do
    alter table("posts") do
      add :filename, :string, size: 2048
    end
  end
end
