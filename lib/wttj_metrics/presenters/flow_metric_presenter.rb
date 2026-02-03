# frozen_string_literal: true

module WttjMetrics
  module Presenters
    # Presenter for flow metrics (cycle time, lead time, throughput, WIP)
    class FlowMetricPresenter < BasePresenter
      TOOLTIPS = {
        'median_cycle_time_days' => "Median time from when work starts on an issue until it's completed.",
        'median_lead_time_days' => 'Median time from issue creation to completion.',
        'median_review_time_days' => 'Median time spent in review states (code review, testing, validation).',
        'weekly_throughput' => 'Number of issues completed in the last 7 days.',
        'current_wip' => 'Work In Progress: issues currently being worked on.'
      }.freeze

      def label
        name.tr('_', ' ')
        .gsub('median ', 'Median ')
            .gsub('days', '')
            .gsub('current ', '')
            .strip
            .capitalize
      end

      def tooltip
        TOOLTIPS[name] || ''
      end

      def unit
        return ' days' if name.include?('days')
        return ' issues' if name.include?('throughput') || name.include?('wip')

        ''
      end
    end
  end
end
