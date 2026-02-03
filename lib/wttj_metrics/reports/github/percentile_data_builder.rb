# frozen_string_literal: true

module WttjMetrics
  module Reports
    module Github
      # Builds percentile data from GitHub metrics for distribution analysis
      # Single Responsibility: Calculate and format percentile statistics for PR metrics
      class PercentileDataBuilder
        include Helpers::StatisticsHelper

        TEAM_COLORS = %w[blue green orange purple pink cyan red lime].freeze

        def initialize(parser, cutoff_date: nil)
          @parser = parser
          @cutoff_date = cutoff_date
        end

        # Time to first review percentiles (in days)
        def time_to_first_review_percentiles
          values = daily_values_for('median_time_to_first_review_days')
          build_percentile_data(values, 'Time to First Review', 'days')
        end

        # Time to merge percentiles (convert hours to days)
        def time_to_merge_percentiles
          values = daily_values_for('median_time_to_merge_hours').map { |v| v / 24.0 }
          build_percentile_data(values, 'Time to Merge', 'days')
        end

        # Time to approval percentiles (in days)
        def time_to_approval_percentiles
          values = daily_values_for('median_time_to_approval_days')
          build_percentile_data(values, 'Time to Approval', 'days')
        end

        # PR size percentiles (additions + deletions)
        def pr_size_percentiles
          additions = daily_values_for('median_additions_per_pr')
          deletions = daily_values_for('median_deletions_per_pr')
          sizes = additions.zip(deletions).map { |addition, deletion| (addition || 0) + (deletion || 0) }

          {
            percentiles: calculate_percentiles(sizes),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            stats: build_stats(sizes),
            unit: 'lines',
            additions: build_percentile_data(additions, 'Additions', 'lines'),
            deletions: build_percentile_data(deletions, 'Deletions', 'lines')
          }
        end

        # Rework cycles percentiles
        def rework_cycles_percentiles
          values = daily_values_for('median_rework_cycles')
          build_percentile_data(values, 'Rework Cycles', 'cycles')
        end

        # Reviews per PR percentiles
        def reviews_per_pr_percentiles
          values = daily_values_for('median_reviews_per_pr')
          build_percentile_data(values, 'Reviews per PR', 'reviews')
        end

        # CI time to green percentiles (in hours)
        def time_to_green_percentiles
          values = daily_values_for('median_time_to_green_hours')
          build_percentile_data(values, 'Time to Green', 'hours')
        end

        # CI success rate distribution
        def ci_success_rate_distribution
          values = daily_values_for('ci_success_rate')
          {
            percentiles: calculate_percentiles(values),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            stats: build_stats(values),
            distribution: build_histogram(values, buckets: [0, 50, 75, 90, 95, 100]),
            unit: '%'
          }
        end

        # Weekly throughput (PRs merged per week)
        def weekly_pr_throughput
          merged = weekly_aggregates_for('merged')
          created = weekly_aggregates_for('created')
          weeks = merged.keys.sort

          {
            labels: weeks.map { |week| format_week_label(week) },
            merged: weeks.map { |week| merged[week] || 0 },
            created: weeks.map { |week| created[week] || 0 },
            percentiles: {
              merged: calculate_percentiles(merged.values),
              created: calculate_percentiles(created.values)
            }
          }
        end

        # Deploy frequency percentiles
        def deploy_frequency_percentiles
          values = daily_values_for('releases_count')
          weekly = weekly_aggregates_for('releases_count')

          {
            daily: build_percentile_data(values, 'Daily Deploys', 'deploys'),
            weekly: build_percentile_data(weekly.values, 'Weekly Deploys', 'deploys')
          }
        end

        # Team comparison data for key metrics
        def team_comparison_data
          teams_data = extract_team_metrics

          {
            labels: teams_data.keys.sort,
            time_to_merge: format_team_metric(teams_data, 'median_time_to_merge_hours', divisor: 24),
            time_to_review: format_team_metric(teams_data, 'median_time_to_first_review_days'),
            reviews_per_pr: format_team_metric(teams_data, 'median_reviews_per_pr'),
            unreviewed_rate: format_team_metric(teams_data, 'unreviewed_pr_rate')
          }
        end

        # Combined percentile data
        def all_percentile_data
          {
            time_to_first_review: time_to_first_review_percentiles,
            time_to_merge: time_to_merge_percentiles,
            time_to_approval: time_to_approval_percentiles,
            pr_size: pr_size_percentiles,
            rework_cycles: rework_cycles_percentiles,
            reviews_per_pr: reviews_per_pr_percentiles,
            time_to_green: time_to_green_percentiles,
            ci_success_rate: ci_success_rate_distribution,
            weekly_throughput: weekly_pr_throughput,
            deploy_frequency: deploy_frequency_percentiles
          }
        end

        private

        def daily_values_for(metric_name)
          daily_data = @parser.metrics_by_category['github_daily'] || []
          daily_data
            .select { |m| m[:metric] == metric_name }
            .select { |m| @cutoff_date.nil? || m[:date] >= @cutoff_date }
            .map { |m| m[:value].to_f }
            .reject(&:zero?)
        end

        def weekly_aggregates_for(metric_name)
          daily_data = @parser.metrics_by_category['github_daily'] || []
          daily_data
            .select { |m| m[:metric] == metric_name }
            .select { |m| @cutoff_date.nil? || m[:date] >= @cutoff_date }
            .group_by { |m| week_key(m[:date]) }
            .transform_values { |metrics| metrics.sum { |m| m[:value].to_f } }
        end

        def extract_team_metrics
          teams = {}
          @parser.metrics_by_category.each do |category, metrics|
            next unless category.start_with?('github:') && category.end_with?('_daily')

            team_name = category.sub('github:', '').sub('_daily', '')
            next if team_name.empty?

            teams[team_name] = metrics
                               .select { |m| @cutoff_date.nil? || m[:date] >= @cutoff_date }
                               .group_by { |m| m[:metric] }
                               .transform_values { |v| v.map { |m| m[:value].to_f } }
          end
          teams
        end

        def format_team_metric(teams_data, metric_name, divisor: 1)
          teams_data.keys.sort.map do |team|
            values = teams_data[team][metric_name] || []
            median = safe_median(values) / divisor
            { team: team, value: median.round(2) }
          end
        end

        def week_key(date_str)
          date = Date.parse(date_str)
          date.strftime('%Y-W%V')
        end

        def format_week_label(week_key)
          _year, week = week_key.split('-W')
          "W#{week}"
        end

        def build_percentile_data(values, label, unit)
          {
            percentiles: calculate_percentiles(values),
            labels: PERCENTILES.map { |percentile| "P#{percentile}" },
            stats: build_stats(values),
            label: label,
            unit: unit
          }
        end

        def build_histogram(values, buckets:)
          return buckets[0..-2].map { |_| { range: '0-0', count: 0 } } if values.empty?

          buckets.each_cons(2).map do |low, high|
            count = values.count { |v| v >= low && v < high }
            count += values.count { |v| v >= high } if high == buckets.last
            { range: "#{low}-#{high}%", count: count }
          end
        end
      end
    end
  end
end
