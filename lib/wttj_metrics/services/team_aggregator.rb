# frozen_string_literal: true

module WttjMetrics
  module Services
    # Aggregates metrics from multiple teams into unified team metrics
    class TeamAggregator
      def initialize(teams_config, available_teams)
        @teams_config = teams_config
        @available_teams = available_teams
        @matcher = TeamMatcher.new(available_teams)
      end

      def aggregate(metrics, strategy: :sum)
        aggregated = []

        @teams_config.defined_teams.each do |unified_name|
          matched_teams = @matcher.match(@teams_config.patterns_for(unified_name, :linear))
          next if matched_teams.empty?

          team_metrics = filter_metrics_for_teams(metrics, matched_teams)
          aggregated.concat(aggregate_metrics_for_team(unified_name, team_metrics, strategy))
        end

        aggregated
      end

      private

      def filter_metrics_for_teams(metrics, teams)
        metrics.select { |m| teams.include?(m[:metric].split(':').first) }
      end

      def aggregate_metrics_for_team(unified_name, metrics, strategy)
        grouped = metrics.group_by { |m| [m[:date], extract_suffix(m[:metric])] }

        grouped.map do |(date, suffix), items|
          value = calculate_value(items, suffix, strategy)
          { date: date, metric: "#{unified_name}:#{suffix}", value: value }
        end
      end

      def extract_suffix(metric)
        metric.split(':')[1..].join(':')
      end

      def calculate_value(items, suffix, _strategy)
        values = items.map { |m| m[:value].to_f }
        return median(values) if average_metric?(suffix)

        values.sum
      end

      def median(values)
        sorted = values.sort
        mid = sorted.length / 2
        return sorted[mid] if sorted.length.odd?

        (sorted[mid - 1] + sorted[mid]) / 2.0
      end

      def average_metric?(suffix)
        suffix.include?('cycle_time') || suffix.include?('lead_time')
      end
    end
  end
end
