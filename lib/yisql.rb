# WIP Port of https://github.com/krisajenkins/yesql
module Yisql
  extend self

  class ConnMysql2
    require 'mysql2'

    def initialize(spec = {})
      spec = spec.merge(host: "localhost", username: "root", as: :hash, symbolize_keys: true)
      @client = ::Mysql2::Client.new(spec)
    end

    def execute(sql, params = {})
      sql = interpolate(sql, params)
      @client.query(sql)
    end

    private

    def interpolate(sql, params)
      params.reduce(sql) { |sql, (name, value)| sql.gsub(/:#{name}\b/, escape(value)) }
    end

    def escape(value)
      case value
      when Numeric then @client.escape(value.to_s)
      when String then "'#{@client.escape(value.to_s)}'"
      when Enumerable then value.map { |v| escape(v) }.join(",")
      else raise "unknown value type #{value.class}"
      end
    end
  end

  def query(path)
    sql = File.read(path).gsub(/\-\-.*$/, '').squeeze.strip
    param_names = sql.scan(/(?<=\:)[_a-z]+/)

    if param_names.empty?
      eval <<-RUBY
        lambda { |conn| conn.execute(sql) }
      RUBY
    else
      eval <<-RUBY
        lambda { |conn, #{param_names.map { |n| "#{n}: nil" }.join(", ")}|
          conn.execute(sql, #{param_names.map { |n| "#{n}: #{n}" }.join(", ")})
        }
      RUBY
    end
  end
end
