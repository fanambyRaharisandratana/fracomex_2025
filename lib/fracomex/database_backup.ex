defmodule Fracomex.DatabaseBackup do
  use GenServer


   

  # Intervalle pour vérifier la plage horaire (60 000 ms = 1 minute)
  @backup_interval 60_000
  # Configuration de la base de données
  @db_name "fracomex"
  @db_user "postgres"
  @db_password "Mgbi@261!"
  @db_host "localhost"
  @db_port "5433"
  # Répertoire pour les sauvegardes à la racine du projet
  @backup_dir Path.expand("backups")
  # Préfixe pour les noms de fichiers de sauvegarde
  @file_prefix "fracomex_database"

  # Plage horaire pour générer des backups
  @start_time "18:10:00"
  @end_time "18:30:00"

  # Démarre le GenServer avec une configuration initiale vide
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Initialisation du GenServer : création du répertoire si nécessaire et planification de la vérification
  def init(state) do
    File.mkdir_p(@backup_dir)  # Crée le répertoire si nécessaire
    schedule_check()
    {:ok, state}
  end

  # Gère les messages reçus : vérifie l'heure, si un backup est nécessaire et en génère un si nécessaire
  def handle_info(:check_backup, state) do
    now = NaiveDateTime.local_now()

    if in_backup_window?(now) do
      if backup_needed_today?() do
        IO.puts("Backup already generated today.")
      else
        IO.puts("Generating backup...")
        backup_database()
        IO.puts("Backup finished successfully.")
      end
    else
      IO.puts("Not within the backup window.")
    end

    # Planifie la prochaine vérification
    schedule_check()
    {:noreply, state}
  end

  # Planifie la prochaine vérification du backup après un certain intervalle
  defp schedule_check() do
    Process.send_after(self(), :check_backup, @backup_interval)
  end

  # Vérifie si l'heure actuelle est dans la fenêtre de sauvegarde définie
  defp in_backup_window?(now) do
    current_time_str = NaiveDateTime.to_time(now) |> Time.to_iso8601()
    start_time = Time.from_iso8601!(@start_time)
    end_time = Time.from_iso8601!(@end_time)
    current_time = Time.from_iso8601!(current_time_str)

    current_time >= start_time and current_time <= end_time
  end

  # Vérifie si un backup a déjà été généré aujourd'hui
  defp backup_needed_today?() do
    today = NaiveDateTime.local_now() |> NaiveDateTime.to_date() |> Date.to_iso8601()
    backup_files = File.ls!(@backup_dir)
    date_prefix = today <> "_"

    Enum.any?(backup_files, fn file ->
      String.starts_with?(file, @file_prefix) and String.contains?(file, date_prefix) and String.ends_with?(file, ".sql")
    end)
  end

  # Génère un backup de la base de données
  defp backup_database() do
    naive_dt_now = NaiveDateTime.local_now()
    date_str = NaiveDateTime.to_date(naive_dt_now) |> Date.to_iso8601() |> String.replace("-", "_")
    time_str = NaiveDateTime.to_time(naive_dt_now)
           |> Time.to_iso8601()
           |> String.replace(":", "_")

    # Nom du fichier de backup
    backup_filename = "#{@backup_dir}/#{@file_prefix}_#{date_str}_#{time_str}.sql"
    # Commande pour générer le backup
    commands = "PGPASSWORD=#{@db_password} pg_dump -h #{@db_host} -p #{@db_port} -U #{@db_user} -d #{@db_name} -f #{backup_filename}"

    # Exécution de la commande et affichage du résultat
    case System.cmd("sh", ["-c", commands]) do
      {output, 0} ->
        IO.puts("Backup finished at #{time_str}...")
      {error, _code} ->
        IO.puts("Error during backup: #{error}")
    end
  end
end
