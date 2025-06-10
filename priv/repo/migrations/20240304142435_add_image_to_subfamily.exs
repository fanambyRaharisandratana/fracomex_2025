defmodule Fracomex.Repo.Migrations.AddImageToSubfamily do
  use Ecto.Migration

  def change do
    alter table("sub_families") do
      add :image, :string
    end
  end
end
