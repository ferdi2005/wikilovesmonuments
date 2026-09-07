# frozen_string_literal: true

namespace :db do
  desc "Esporta i dati delle tabelle applicative in un file JSON compresso con Gzip"
  task :export_data, [:filename] => :environment do |_t, args|
    require "zlib"
    require "json"

    filename = args[:filename].presence || Rails.root.join("tmp", "wlm_dump_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json.gz").to_s
    FileUtils.mkdir_p(File.dirname(filename))

    models = [
      Town,
      Nophoto,
      Monument
    ]

    puts "Avvio esportazione dati in: #{filename}"
    total_records = 0

    Zlib::GzipWriter.open(filename) do |gz|
      models.each do |model|
        next unless ActiveRecord::Base.connection.table_exists?(model.table_name)

        count = model.unscoped.count
        puts "Esportazione #{model.name} (#{count} record)..."

        model.unscoped.find_in_batches(batch_size: 1000) do |batch|
          batch_data = batch.map do |record|
            record.attributes.transform_values do |val|
              (val.is_a?(Float) && (val.infinite? || val.nan?)) ? nil : val
            end
          end
          payload = JSON.generate({ model: model.name, table: model.table_name, records: batch_data })
          gz.puts(payload)
          total_records += batch.size
        end
      end
    end

    size_mb = (File.size(filename).to_f / (1024 * 1024)).round(2)
    puts "Esportazione completata: #{total_records} record salvati (#{size_mb} MB) in #{filename}"
  end

  desc "Importa i dati da un file JSON compresso generato da db:export_data"
  task :import_data, [:filename] => :environment do |_t, args|
    require "zlib"
    require "json"

    filename = args[:filename].presence
    abort "Uso: rake db:import_data[percorso/file.json.gz]" unless filename && File.exist?(filename)

    conn = ActiveRecord::Base.connection
    adapter = conn.adapter_name.downcase

    puts "Avvio importazione dati da: #{filename} (adapter: #{adapter})"

    # Disabilita temporaneamente i controlli di foreign key
    if adapter.include?("mysql")
      conn.execute("SET FOREIGN_KEY_CHECKS = 0;")
    elsif adapter.include?("postgres")
      conn.execute("SET session_replication_role = 'replica';")
    elsif adapter.include?("sqlite")
      conn.execute("PRAGMA foreign_keys = OFF;")
    end

    total_imported = 0

    begin
      Zlib::GzipReader.open(filename) do |gz|
        gz.each_line do |line|
          data = JSON.parse(line)
          model = data["model"].constantize
          records = data["records"]

          next if records.empty?

          model.insert_all(records)
          total_imported += records.size
          print "."
          $stdout.flush
        end
      end
      puts "\nImportazione completata con successo: #{total_imported} record importati!"
    ensure
      # Riabilita sempre i controlli di foreign key
      if adapter.include?("mysql")
        conn.execute("SET FOREIGN_KEY_CHECKS = 1;")
      elsif adapter.include?("postgres")
        conn.execute("SET session_replication_role = 'DEFAULT';")
      elsif adapter.include?("sqlite")
        conn.execute("PRAGMA foreign_keys = ON;")
      end
    end
  end
end
