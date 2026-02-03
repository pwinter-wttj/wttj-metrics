# frozen_string_literal: true

module WttjMetrics
  module Presenters
    # Presenter for cycle metrics (velocity, commitment accuracy, carryover)
    class CycleMetricPresenter < BasePresenter
      TOOLTIPS = {
        'median_cycle_velocity' => 'Median story points completed per cycle across completed cycles (excluding zero-velocity cycles).',
        'cycle_commitment_accuracy' => 'Median percentage of planned work completed across all completed cycles.',
        'cycle_carryover_count' => 'Median number of issues carried over per completed cycle.'
      }.freeze

      def label
        name.tr('_', ' ')
        .gsub('median ', 'Median ')
            .gsub('current ', '')
            .gsub('cycle ', '')
            .strip
            .capitalize
      end

      def tooltip
        TOOLTIPS[name] || ''
      end

      def unit
        name.include?('accuracy') ? '%' : ''
      end
    end
  end
end
