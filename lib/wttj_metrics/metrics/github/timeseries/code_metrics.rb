# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Github
      module Timeseries
        class CodeMetrics
          include Helpers::StatisticsHelper

          def initialize
            @additions = []
            @deletions = []
          end

          def record(pull_request)
            @additions << (pull_request[:additions] || pull_request['additions'] || 0).to_f
            @deletions << (pull_request[:deletions] || pull_request['deletions'] || 0).to_f
          end

          def metrics
            {
              median_additions_per_pr: safe_median(@additions, precision: 2),
              median_deletions_per_pr: safe_median(@deletions, precision: 2)
            }
          end
        end
      end
    end
  end
end
