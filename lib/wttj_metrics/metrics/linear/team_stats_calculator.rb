# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Linear
      # Calculates aggregate statistics for team cycles
      # Single Responsibility: Team statistics calculation
      class TeamStatsCalculator
        include Helpers::StatisticsHelper

        COUNTABLE_STATUSES = %w[completed active].freeze
        METRIC_DEFINITIONS = [
          { key: :median_velocity, field: :velocity, precision: 0 },
          { key: :median_tickets_per_cycle, field: :completed_issues, precision: 0 },
          { key: :median_assignees, field: :assignee_count, precision: 0 },
          { key: :median_completion_rate, field: :completion_rate, precision: 0 },
          { key: :median_tickets_per_day, field: :tickets_per_day, precision: 0 },
          { key: :median_scope_change, field: :scope_change, precision: 0 }
        ].freeze

        def initialize(cycles_by_team)
          @cycles_by_team = cycles_by_team
        end

        def calculate
          @cycles_by_team.transform_values { |cycles| calculate_team_stats(cycles) }
        end

        private

        def calculate_team_stats(cycles)
          active_cycles = select_active_cycles(cycles)

          base_stats(cycles, active_cycles).merge(calculated_medians(active_cycles))
        end

        def base_stats(cycles, active_cycles)
          {
            total_cycles: cycles.size,
            cycles_with_data: active_cycles.size,
            total_carryover: sum(active_cycles, :carryover)
          }
        end

        def calculated_medians(active_cycles)
          METRIC_DEFINITIONS.to_h do |metric|
            [metric[:key], median(active_cycles, metric[:field], precision: metric[:precision])]
          end
        end

        def select_active_cycles(cycles)
          cycles.select { |cycle| countable_cycle?(cycle) }
        end

        def countable_cycle?(cycle)
          COUNTABLE_STATUSES.include?(cycle[:status]) && cycle_has_issues?(cycle)
        end

        def cycle_has_issues?(cycle)
          (cycle[:total_issues] || 0).positive?
        end

        def median(cycles, field, precision: 1)
          values = cycles.map { |cycle| field_value(cycle, field).to_f }
          safe_median(values, precision: precision)
        end

        def sum(cycles, field)
          cycles.sum { |cycle| field_value(cycle, field) }
        end

        def field_value(cycle, field)
          cycle[field] || 0
        end
      end
    end
  end
end
