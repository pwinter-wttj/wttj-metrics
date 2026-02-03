# frozen_string_literal: true

module WttjMetrics
  module Reports
    module Linear
      # Handles formatting of metrics for Excel reports
      # Single Responsibility: Data formatting and descriptions
      class ExcelFormatter
        METRIC_DESCRIPTIONS = {
          'median_cycle_time_days' => 'Median time from work start to completion',
          'median_lead_time_days' => 'Median time from creation to completion',
          'weekly_throughput' => 'Issues completed in last 7 days',
          'current_wip' => 'Work In Progress count',
          'current_cycle_velocity' => 'Story points completed in current cycle',
          'cycle_commitment_accuracy' => 'Median percentage of planned work completed',
          'cycle_carryover_count' => 'Median issues carried over per completed cycle',
          'completion_rate' => 'Percentage of issues completed',
          'median_blocked_time_hours' => 'Median time issues are blocked',
          'median_backlog_age_days' => 'Median age of backlog items',
          'total_bugs' => 'Total bugs in workspace',
          'open_bugs' => 'Bugs not yet completed',
          'closed_bugs' => 'Bugs completed or canceled',
          'bugs_created_last_30d' => 'New bugs in last 30 days',
          'bugs_closed_last_30d' => 'Bugs resolved in last 30 days',
          'median_bug_resolution_days' => 'Median time to resolve a bug',
          'bug_ratio' => 'Percentage of issues that are bugs'
        }.freeze

        UNIT_MAPPINGS = {
          'days' => ' days',
          'throughput' => ' issues',
          'accuracy' => '%',
          'rate' => '%',
          'hours' => 'h'
        }.freeze

        def description_for(metric)
          METRIC_DESCRIPTIONS[metric] || ''
        end

        def format_metric_value(metric, value)
          unit = determine_unit(metric)
          "#{value.round(1)}#{unit}"
        end

        def format_bug_row(metric)
          label = metric[:metric].tr('_', ' ').gsub('bugs ', '').gsub('bug ', '').capitalize
          unit = bug_unit(metric[:metric])
          value = format_bug_value(metric[:metric], metric[:value])

          [label, "#{value}#{unit}", description_for(metric[:metric])]
        end

        def format_cycle_row(cycle)
          [
            cycle[:name],
            cycle[:status],
            cycle[:progress]&.round(1) || 0,
            "#{cycle[:completed_issues] || 0}/#{cycle[:total_issues] || 0}",
            cycle[:velocity] || 0,
            cycle[:assignee_count] || 0,
            cycle[:tickets_per_day]&.round(2) || 0,
            cycle[:carryover] || 0,
            cycle[:scope_change]&.round(1) || 0
          ]
        end

        private

        def determine_unit(metric)
          UNIT_MAPPINGS.find { |key, _| metric.include?(key) }&.last || ''
        end

        def bug_unit(metric_name)
          case metric_name
          when 'median_bug_resolution_days' then ' days'
          when 'bug_ratio' then '%'
          else ''
          end
        end

        def format_bug_value(metric_name, value)
          if metric_name.include?('days') || metric_name.include?('ratio')
            value.round(1)
          else
            value.to_i
          end
        end
      end
    end
  end
end
