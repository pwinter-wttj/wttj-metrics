# frozen_string_literal: true

require 'spec_helper'
require 'wttj_metrics/metrics/github/collaboration_calculator'

RSpec.describe WttjMetrics::Metrics::Github::CollaborationCalculator do
  subject(:calculator) { described_class.new(pull_requests) }

  let(:pull_requests) { [] }

  describe '#calculate' do
    context 'with no data' do
      it 'returns empty hash' do
        expect(calculator.calculate).to eq({})
      end
    end

    context 'with data' do
      let(:pull_requests) do
        [
          {
            reviews: { totalCount: 2, nodes: [{ state: 'APPROVED' }, { state: 'CHANGES_REQUESTED' }] },
            comments: { totalCount: 3 }
          },
          {
            reviews: { totalCount: 0, nodes: [] },
            comments: { totalCount: 1 }
          }
        ]
      end

      it 'calculates metrics correctly' do
        stats = calculator.calculate

        # Reviews: 2 + 0 = 2. Count = 2. Avg = 1.0
        expect(stats[:median_reviews_per_pr]).to eq(1.0)

        # Comments: 3 + 1 = 4. Count = 2. Avg = 2.0
        expect(stats[:median_comments_per_pr]).to eq(2.0)

        # Rework: 1 CHANGES_REQUESTED. Count = 2. Avg = 0.5
        expect(stats[:median_rework_cycles]).to eq(0.5)

        # Unreviewed: 1 PR with 0 reviews. Count = 2. Rate = 50%
        expect(stats[:unreviewed_pr_rate]).to eq(50.0)
      end
    end
  end
end
