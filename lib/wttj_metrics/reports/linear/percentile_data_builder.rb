# frozen_string_literal: true

module WttjMetrics
  module Reports
    module Linear
      # Builds percentile data from timeseries metrics for distribution analysis
      # Single Responsibility: Calculate and format percentile statistics
      class PercentileDataBuilder
        include Helpers::StatisticsHelper

        TEAM_COLORS = %w[blue green orange purple pink cyan red lime].freeze

        def initialize(parser, teams: [], cutoff_date: nil, available_teams: [])
          @parser = parser
          @teams = teams
          @cutoff_date = cutoff_date
          @available_teams = available_teams
        end

        # Daily throughput percentiles (tickets created/completed per day)
        def throughput_percentiles
          created = daily_values_for('tickets_created')
          completed = daily_values_for('tickets_completed')

          {
            created: calculate_percentiles(created),
            completed: calculate_percentiles(completed),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" }
          }
        end

        # Weekly throughput distribution
        def weekly_throughput_data
          created = weekly_aggregates_for('tickets_created')
          completed = weekly_aggregates_for('tickets_completed')

          weeks = created.keys.sort

          {
            labels: weeks.map { |week| format_week_label(week) },
            created: weeks.map { |week| created[week] || 0 },
            completed: weeks.map { |week| completed[week] || 0 },
            percentiles: {
              created: calculate_percentiles(created.values),
              completed: calculate_percentiles(completed.values)
            }
          }
        end

        # Bug resolution time percentiles by team (MTTR)
        # Only shows selected/filtered teams
        def bug_mttr_by_team
          bugs_data = @parser.metrics_for('bugs_by_team')
          teams_mttr = {}

          bugs_data.each do |metric|
            next unless metric[:metric].end_with?(':mttr')

            team = metric[:metric].split(':').first
            next if @teams.any? && !@teams.include?(team)

            teams_mttr[team] ||= []
            teams_mttr[team] << metric[:value].to_f
          end

          format_team_comparison(teams_mttr, 'MTTR (days)')
        end

        # Cycle velocity distribution (excludes upcoming cycles and zero-velocity cycles)
        def cycle_velocity_distribution
          velocities = []

          completed_cycle_identifiers.each do |cycle_id|
            velocity_metric = find_cycle_metric(cycle_id, ':velocity')
            next unless velocity_metric

            value = velocity_metric[:value].to_f
            velocities << value if value.positive?
          end

          {
            percentiles: calculate_percentiles(velocities),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            stats: {
              min: velocities.min&.round(1) || 0,
              max: velocities.max&.round(1) || 0,
              avg: safe_median(velocities),
              count: velocities.size
            }
          }
        end

        # Cycle completion rate distribution (only completed cycles)
        def completion_rate_distribution
          rates = []

          completed_cycle_identifiers.each do |cycle_id|
            progress_metric = find_cycle_metric(cycle_id, ':progress')
            next unless progress_metric

            rates << progress_metric[:value].to_f
          end

          {
            percentiles: calculate_percentiles(rates),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            distribution: build_histogram(rates, buckets: [0, 25, 50, 75, 90, 100]),
            stats: {
              min: rates.min&.round(1) || 0,
              max: rates.max&.round(1) || 0,
              avg: safe_median(rates),
              count: rates.size
            }
          }
        end

        # Combined percentile chart data
        def all_percentile_data
          {
            throughput: throughput_percentiles,
            weekly_throughput: weekly_throughput_data,
            bug_mttr: bug_mttr_by_team,
            velocity: cycle_velocity_distribution,
            completion: completion_rate_distribution
          }
        end

        private

        def daily_values_for(metric_name)
          all_timeseries_data
            .select { |m| m[:metric] == metric_name }
            .select { |m| within_cutoff?(m[:date]) }
            .map { |m| m[:value].to_f }
        end

        def weekly_aggregates_for(metric_name)
          all_timeseries_data
            .select { |m| m[:metric] == metric_name }
            .select { |m| within_cutoff?(m[:date]) }
            .group_by { |m| week_key(m[:date]) }
            .transform_values { |metrics| metrics.sum { |m| m[:value].to_f } }
        end

        def all_timeseries_data
          @all_timeseries_data ||= @parser.metrics_by_category['timeseries'] || []
        end

        def all_cycle_data
          @all_cycle_data ||= @parser.metrics_by_category['cycle'] || []
        end

        # Returns cycle identifiers (e.g., "Team:Cycle 1") for completed/active cycles only
        def completed_cycle_identifiers
          @completed_cycle_identifiers ||= begin
            cycle_statuses = {}

            all_cycle_data.each do |metric|
              next unless metric[:metric].end_with?(':status')
              next unless within_cutoff?(metric[:date])

              cycle_id = metric[:metric].sub(':status', '')
              cycle_statuses[cycle_id] = metric[:value].to_s.downcase
            end

            # Only include completed cycles (exclude upcoming)
            cycle_statuses.select { |_id, status| status == 'completed' }.keys
          end
        end

        # Find a specific metric for a cycle
        def find_cycle_metric(cycle_id, metric_suffix)
          all_cycle_data.find do |metric|
            metric[:metric] == "#{cycle_id}#{metric_suffix}" && within_cutoff?(metric[:date])
          end
        end

        def within_cutoff?(date_value)
          return true if @cutoff_date.nil?

          date = date_value.is_a?(Date) ? date_value : Date.parse(date_value.to_s)
          cutoff = @cutoff_date.is_a?(Date) ? @cutoff_date : Date.parse(@cutoff_date.to_s)
          date >= cutoff
        end

        def week_key(date_str)
          date = Date.parse(date_str)
          date.strftime('%Y-W%V')
        end

        def format_week_label(week_key)
          _year, week = week_key.split('-W')
          "W#{week}"
        end

        def format_team_comparison(teams_data, metric_label)
          teams = teams_data.keys.sort
          {
            labels: teams,
            datasets: teams.each_with_index.map do |team, idx|
              values = teams_data[team]
              {
                label: team,
                data: calculate_percentiles(values),
                backgroundColor: TEAM_COLORS[idx % TEAM_COLORS.length],
                value: safe_median(values)
              }
            end,
            percentile_labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            metric_label: metric_label
          }
        end

        def build_histogram(values, buckets:)
          return buckets[0..-2].map { { range: "#{buckets[0]}-#{buckets[1]}", count: 0 } } if values.empty?

          counts = buckets.each_cons(2).map do |low, high|
            count = values.count { |v| v >= low && v < high }
            { range: "#{low}-#{high}%", count: count }
          end

          # Handle 100% bucket
          counts.last[:count] += values.count { |v| v >= buckets[-1] }
          counts
        end
      end
    end
  end
end
