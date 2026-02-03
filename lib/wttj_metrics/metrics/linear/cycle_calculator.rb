# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Linear
      # Calculates cycle/sprint metrics
      class CycleCalculator
        include Helpers::StatisticsHelper

        def initialize(cycles, today: Date.today)
          @cycles = cycles
          @today = today
        end

        def calculate
          {
            median_cycle_velocity: median_cycle_velocity,
            cycle_commitment_accuracy: cycle_commitment_accuracy,
            cycle_carryover_count: cycle_carryover_count
          }
        end

        def to_rows
          rows = calculate.map do |metric, value|
            [today.to_s, 'cycle_metrics', metric.to_s, value]
          end

          rows + cycle_details_rows
        end

        private

        attr_reader :cycles, :today

        def median_cycle_velocity
          return 0 if completed_cycles.empty?

          velocities = completed_cycles.map { |cycle| completed_points(cycle).to_f }
                                     .select(&:positive?)
          return 0 if velocities.empty?

          safe_median(velocities, precision: 1)
        end

        def cycle_commitment_accuracy
          return 0 if completed_cycles.empty?

          accuracies = completed_cycles.map { |cycle| cycle_completion_percentage(cycle).to_f }
          safe_median(accuracies, precision: 2)
        end

        def cycle_carryover_count
          return 0 if completed_cycles.empty?

          carryovers = completed_cycles.map { |cycle| carryover_count_for(cycle).to_f }
          safe_median(carryovers, precision: 1)
        end

        def completed_cycles
          @completed_cycles ||= cycles.select { |cycle| cycle['completedAt'] }
        end

        def cycle_completion_percentage(cycle)
          cycle_issues = cycle.dig('issues', 'nodes') || []
          return 0 if cycle_issues.empty?

          completed = cycle_issues.count { |issue| issue_completed?(issue) }
          calculate_percentage(completed, cycle_issues.size, precision: 2)
        end

        def carryover_count_for(cycle)
          uncompleted = cycle.dig('uncompletedIssuesUponClose', 'nodes') || []
          uncompleted.size
        end

        def issue_completed?(issue)
          issue.dig('state', 'type') == 'completed'
        end

        def cycle_details_rows
          cycles.flat_map { |cycle| CycleDetailBuilder.new(cycle, today).to_rows }
        end

        def current_cycle
          @current_cycle ||= cycles.find { |cycle| cycle_active?(cycle) }
        end

        def cycle_active?(cycle)
          return false unless cycle['startsAt'] && cycle['endsAt']

          starts = Date.parse(cycle['startsAt'])
          ends = Date.parse(cycle['endsAt'])
          today.between?(starts, ends)
        end

        def last_completed_cycle
          @last_completed_cycle ||= cycles
                                    .select { |c| c['completedAt'] }
                                    .max_by { |c| c['completedAt'] }
        end

        def completed_points(cycle)
          cycle_issues = cycle.dig('issues', 'nodes') || []
          cycle_issues.sum do |issue|
            issue_completed?(issue) ? (issue['estimate'] || 0) : 0
          end
        end
      end

      # Builds detail rows for a single cycle
      class CycleDetailBuilder
        include Helpers::Linear::IssueHelper
        include Helpers::StatisticsHelper

        METRICS = %i[
          total_issues completed_issues bug_count velocity planned_points
          completion_rate carryover progress duration_days tickets_per_day
          assignee_count status scope_change initial_scope final_scope
        ].freeze

        def initialize(cycle, today)
          @cycle = cycle
          @today = today
        end

        def to_rows
          METRICS.map do |metric|
            [cycle_date, 'cycle', "#{cycle_key}:#{metric}", send(metric)]
          end
        end

        private

        attr_reader :cycle, :today

        def cycle_key
          "#{team_name}:#{cycle_name}"
        end

        def cycle_name
          cycle['name'] || "Cycle #{cycle['number']}"
        end

        def team_name
          cycle.dig('team', 'name') || 'Unknown'
        end

        def cycle_date
          return parse_cycle_date(cycle['completedAt']) if cycle['completedAt']
          return ends_at.to_s if ends_at && ends_at <= today

          today.to_s
        end

        def starts_at
          @starts_at ||= parse_cycle_date(cycle['startsAt'])
        end

        def ends_at
          @ends_at ||= parse_cycle_date(cycle['endsAt'])
        end

        def parse_cycle_date(date_string)
          return nil unless date_string

          Date.parse(date_string)
        end

        def cycle_issues
          @cycle_issues ||= cycle.dig('issues', 'nodes') || []
        end

        def total_issues
          cycle_issues.size
        end

        def completed_issues
          cycle_issues.count { |issue| issue_completed?(issue) }
        end

        def bug_count
          cycle_issues.count { |issue| issue_is_bug?(issue) }
        end

        def velocity
          cycle_issues.sum do |issue|
            issue_completed?(issue) ? (issue['estimate'] || 0) : 0
          end
        end

        def issue_completed?(issue)
          issue.dig('state', 'type') == 'completed'
        end

        def planned_points
          cycle_issues.sum { |i| i['estimate'] || 0 }
        end

        def completion_rate
          calculate_percentage(completed_issues, total_issues, precision: 0)
        end

        def carryover
          (cycle.dig('uncompletedIssuesUponClose', 'nodes') || []).size
        end

        def progress
          calculate_percentage(completed_issues, total_issues, precision: 0)
        end

        def duration_days
          starts_at && ends_at ? (ends_at - starts_at).to_i : 0
        end

        def tickets_per_day
          return 0 unless duration_days.positive?

          (completed_issues.to_f / duration_days).round(2)
        end

        def assignee_count
          cycle_issues.filter_map { |i| i.dig('assignee', 'id') }.uniq.size
        end

        def status
          return 'completed' if cycle['completedAt']
          return 'active' if starts_at && ends_at && today.between?(starts_at, ends_at)
          return 'upcoming' if starts_at && today < starts_at

          'past'
        end

        def scope_change
          return 0.0 if scope_history.empty?

          initial = initial_scope.to_f
          final = final_scope.to_f
          return 0.0 if initial.zero?

          (((final - initial) / initial) * Helpers::StatisticsHelper::PERCENTAGE_MULTIPLIER).round(1)
        end

        def initial_scope
          return 0 if scope_history.empty?

          scope_history.first.to_i
        end

        def final_scope
          return 0 if scope_history.empty?

          scope_history.last.to_i
        end

        def scope_history
          @scope_history ||= cycle['scopeHistory'] || []
        end
      end
    end
  end
end
