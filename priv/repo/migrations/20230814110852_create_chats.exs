defmodule BdfrBrowser.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats, primary_key: false) do
      add :id, :string, primary_key: true, size: 1024
      add :accounts, {:array, :string}
    end

    create table(:messages, primary_key: false) do
      add :id, :string, primary_key: true, size: 256
      add :author, :string
      add :message, :text
      add :posted_at, :utc_datetime

      add :chat_id, references(:chats, type: :string)
    end

    create index("messages", :chat_id)
  end
end
