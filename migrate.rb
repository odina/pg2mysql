#!/usr/bin/ruby

require 'active_record'
require 'mysql2'
require 'pg'
require 'yaml'

dbconfig = YAML.load(File.read('config/database.yml'))

ActiveRecord::Base.establish_connection(dbconfig)

ignore_tables = %w(schema_migrations)
t = Time.new

f = File.open("dumps/data-#{t.to_date}.sql", 'w')
f.write("SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\";\n")
f.write("SET time_zone = \"+00:00\";\n\n")


# enclose in '' if a field has an uppercase
def pad_if_with_upcase(str)
  return str =~ /[A-Z]/ ? "\"#{str}\"" : str
end

# enclose in '' if a field is reserved in mysql
def pad_if_reserved(str)
  reserved = [
    'ignore',
    'index'
  ]

  return reserved.include?(str) ? "`#{str}`" : str
end

ActiveRecord::Base.connection.tables.each do |table|
    if !ignore_tables.include? table
        #c.name , c.type.to_s , c.limit.to_s
        fields    = ActiveRecord::Base.connection.columns(table).map { |x| x.name }
        pg_fields    = fields.map { |x| pad_if_with_upcase(x) }
        mysql_fields = fields.map { |x| pad_if_reserved(x) }

        results = ActiveRecord::Base.connection.execute("select #{pg_fields.join(',')} from #{table}")

        f.write("#Table #{table}\n");
        puts "Processing table #{table}"
        results.each do |data|
          str = data.values.map do |v|
            if v.nil?
              'NULL'
            else
              case v
                when 't'
                  1
                when 'f'
                  0
                else
                  s = v.gsub(/\\/,"\\\\\\").
                        gsub(/\r\n+/,"\\\\n").
                        gsub(/\n+/,"\\\\n").
                        gsub(/'/,"\\\\'")
                  "'#{s}'"
              end
            end
          end.join(',')

          f.write("insert into #{table} (#{mysql_fields.join(',')}) values (#{str});\n")
        end
        f.write("\n\n");
    end
end

f.close
