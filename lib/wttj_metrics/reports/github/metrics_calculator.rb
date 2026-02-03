# frozen_string_literal: true

module WttjMetrics
  module Reports
    module Github
      # Calculates metrics from raw data
      class MetricsCalculator
        def initialize(metrics_data)
          @metrics_data = metrics_data || []
        end

        def latest(metric_name)
          @metrics_data
            .select { |m| m[:metric] == metric_name }
            .max_by { |m| m[:date] }
            &.dig(:value) || 0
        end

        def latest_or_nil(metric_name)
          @metrics_data
            .select { |m| m[:metric] == metric_name }
            .max_by { |m| m[:date] }
            &.dig(:value)
        end

        def history(metric_name)
          @metrics_data
            .select { |m| m[:metric] == metric_name }
            .sort_by { |m| m[:date] }
            .map { |m| { date: m[:date], value: m[:value] } }
        end
      end
    end
  end
end
