# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Linear
      # Calculates timeseries metrics from Linear issues
      # Follows composition pattern similar to GitHub implementation
      class TimeseriesCalculator < Base
        include Helpers::StatisticsHelper

        def to_rows
          process_issues
          collect_rows
        end

        private

        def process_issues
          @ticket_metrics = Timeseries::TicketMetrics.new
          @bug_metrics = Timeseries::BugMetrics.new
          @transition_metrics = Timeseries::TransitionMetrics.new

          issues.each do |issue|
            process_issue(issue)
          end
        end

        def process_issue(issue)
          process_creation(issue)
          process_completion(issue)
          @bug_metrics.record_team_stats(issue)
          process_transitions(issue)
        end

        def process_creation(issue)
          return unless issue['createdAt']

          date = parse_date(issue['createdAt'], format: :string)
          return unless date

          @ticket_metrics.record_creation(date, issue)
          @bug_metrics.record_creation(date, issue)
        end

        def process_completion(issue)
          return unless issue['completedAt']

          date = parse_date(issue['completedAt'], format: :string)
          return unless date

          @ticket_metrics.record_completion(date, issue)
          @bug_metrics.record_completion(date, issue)
        end

        def process_transitions(issue)
          history = issue.dig('history', 'nodes') || []

          history.each do |event|
            next unless event['createdAt']

            date = parse_date(event['createdAt'], format: :string)
            @transition_metrics.record_transitions(date, issue) if date
          end
        end

        def collect_rows
          rows = []
          rows.concat(@ticket_metrics.to_rows('timeseries'))
          rows.concat(@bug_metrics.to_rows('timeseries'))
          rows.concat(@transition_metrics.to_rows)
          rows.concat(team_bug_stats_rows)
          rows
        end

        def team_bug_stats_rows
          @bug_metrics.stats_by_team.flat_map do |team, stats|
            [
              [today.to_s, 'bugs_by_team', "#{team}:created", stats[:created]],
              [today.to_s, 'bugs_by_team', "#{team}:closed", stats[:closed]],
              [today.to_s, 'bugs_by_team', "#{team}:open", stats[:open]],
              [today.to_s, 'bugs_by_team', "#{team}:mttr", calculate_mttr(stats[:resolution_times])]
            ]
          end
        end

        def calculate_mttr(resolution_times)
          return 0 if resolution_times.empty?

          safe_median(resolution_times, precision: 1)
        end
      end
    end
  end
end
