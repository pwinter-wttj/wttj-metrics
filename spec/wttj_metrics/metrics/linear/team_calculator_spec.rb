# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::TeamCalculator do
  subject(:calculator) { described_class.new(issues, today: today) }

  # Setup
  let(:today) { Date.new(2024, 12, 5) }
  let(:issues) { [] }

  describe '#calculate' do
    subject(:result) { calculator.calculate }

    context 'with completed issues' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-20T10:00:00Z',
            'completedAt' => '2024-11-25T10:00:00Z'
          },
          {
            'createdAt' => '2024-11-22T10:00:00Z',
            'completedAt' => '2024-11-28T10:00:00Z'
          },
          {
            'createdAt' => '2024-11-25T10:00:00Z',
            'completedAt' => nil
          }
        ]
      end

      it 'calculates completion rate', :aggregate_failures do
        # 2 out of 3 issues completed = 66.67%
        expect(result[:completion_rate]).to be_within(0.1).of(66.67)
      end
    end

    context 'with blocked time history' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-20T10:00:00Z',
            'history' => {
              'nodes' => [
                {
                  'createdAt' => '2024-11-21T10:00:00Z',
                  'toState' => { 'name' => 'Blocked' }
                },
                {
                  'createdAt' => '2024-11-21T14:00:00Z',
                  'fromState' => { 'name' => 'Blocked' },
                  'toState' => { 'name' => 'In Progress' }
                }
              ]
            }
          }
        ]
      end

      it 'calculates median blocked time in hours' do
        # 4 hours blocked
        expect(result[:median_blocked_time_hours]).to eq(4.0)
      end
    end

    context 'with no issues' do
      # Setup
      let(:issues) { [] }

      it 'returns zero for all metrics', :aggregate_failures do
        expect(result[:completion_rate]).to eq(0)
        expect(result[:median_blocked_time_hours]).to eq(0)
      end
    end

    context 'with issues outside 30-day window' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-10-01T10:00:00Z', # More than 30 days ago
            'completedAt' => '2024-10-05T10:00:00Z'
          }
        ]
      end

      it 'excludes old issues from completion rate' do
        expect(result[:completion_rate]).to eq(0)
      end
    end
  end

  describe '#to_rows' do
    subject(:rows) { calculator.to_rows }

    # Setup
    let(:issues) { [] }

    it 'returns rows in expected format' do
      expect(rows).to all(match([today.to_s, 'team', kind_of(String), kind_of(Numeric)]))
    end

    it 'includes all team metrics', :aggregate_failures do
      metric_names = rows.map { |r| r[2] }

      expect(metric_names).to include('completion_rate', 'median_blocked_time_hours')
    end
  end
end
