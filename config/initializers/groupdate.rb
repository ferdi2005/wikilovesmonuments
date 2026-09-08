# frozen_string_literal: true

Groupdate.week_start = :monday

# Su MariaDB ToolsDB (Wikimedia Toolforge), le tabelle dei fusi orari nominati (es. 'Europe/Rome')
# non sono caricate nel database di sistema mysql e CONVERT_TZ('Europe/Rome') restituisce NULL.
# MariaDB supporta nativamente la conversione con offset numerico (es. '+02:00') senza tabelle di sistema.
if ENV["TOOLFORGE"].to_s.downcase == "true"
  module GroupdateMysqlTimezonePatch
    def time_zone_support?(_relation)
      true
    end
  end

  module GroupdateMySQLAdapterPatch
    def group_clause
      offset = Time.current.in_time_zone(@time_zone).strftime("%:z")
      tz_mock = Struct.new(:tzinfo).new(Struct.new(:name).new(offset))
      orig_tz = @time_zone
      @time_zone = tz_mock
      result = super
      @time_zone = orig_tz
      result
    end
  end

  Groupdate::Magic::Relation.prepend(GroupdateMysqlTimezonePatch)
  if defined?(Groupdate::Adapters::MySQLAdapter)
    Groupdate::Adapters::MySQLAdapter.prepend(GroupdateMySQLAdapterPatch)
  end
  if defined?(Groupdate::RelationBuilder)
    Groupdate::RelationBuilder.prepend(GroupdateMySQLAdapterPatch)
  end
end
