# frozen_string_literal: true

module WttjMetrics
  module Presenters
    # Presenter for team metrics (completion rate, blocked time)
    class TeamMetricPresenter < BasePresenter
      TOOLTIPS = {
        'completion_rate' => 'Percentage of issues completed vs total issues.',
        'median_blocked_time_hours' => 'Median hours issues spend in blocked state.'
      }.freeze

      def label
        name.tr('_', ' ')
        .gsub('median ', 'Median ')
            .strip
            .capitalize
      end

      def tooltip
        TOOLTIPS[name] || ''
      end

      def unit
        return '%' if name.include?('rate')
        return 'h' if name.include?('hours')

        ''
      end
    end
  end
end
