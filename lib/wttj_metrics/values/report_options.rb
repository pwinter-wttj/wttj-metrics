# frozen_string_literal: true

module WttjMetrics
  module Values
    # Value object for report command options
    class ReportOptions
      attr_reader :output, :days, :teams, :excel_enabled, :excel_path, :teams_config, :start_date, :end_date, :source

      def initialize(options_hash)
        @output = options_hash[:output]
        @source = options_hash[:source]
        @teams = determine_teams(options_hash)
        @excel_enabled = options_hash[:excel]
        @excel_path = options_hash[:excel_path]
        @teams_config = options_hash[:teams_config]
        @start_date = parse_date(options_hash[:start_date])
        @end_date = parse_date(options_hash[:end_date]) || Date.today
        @days = calculate_days(options_hash[:days])
      end

      private

      def parse_date(date_string)
        return nil unless date_string

        Date.parse(date_string)
      end

      def calculate_days(default_days)
        return default_days unless @start_date

        (@end_date - @start_date).to_i
      end

      def determine_teams(options_hash)
        options_hash[:all_teams] ? :all : options_hash[:teams]
      end
    end
  end
end
