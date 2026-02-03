# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::FlowCalculator do
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
            'createdAt' => '2024-12-01T10:00:00Z',
            'startedAt' => '2024-12-02T10:00:00Z',
            'completedAt' => '2024-12-04T10:00:00Z',
            'state' => { 'type' => 'completed' }
          },
          {
            'createdAt' => '2024-12-01T10:00:00Z',
            'startedAt' => '2024-12-01T14:00:00Z',
            'completedAt' => '2024-12-03T10:00:00Z',
            'state' => { 'type' => 'completed' }
          }
        ]
      end

      it 'calculates all flow metrics' do
        # Exercise & Verify
        expect(result).to include(
          :median_cycle_time_days,
          :median_lead_time_days,
          :weekly_throughput,
          :current_wip
        )
      end

      it 'calculates cycle time as median time from start to completion' do
        # Issue 1: 2 days, Issue 2: ~1.83 days, Average: ~1.92
        expect(result[:median_cycle_time_days]).to be_within(0.1).of(1.92)
      end

      it 'calculates lead time as median time from creation to completion' do
        # Issue 1: 3 days, Issue 2: 2 days, Average: 2.5
        expect(result[:median_lead_time_days]).to be_within(0.1).of(2.5)
      end

      it 'counts weekly throughput' do
        expect(result[:weekly_throughput]).to eq(2)
      end
    end

    context 'with in-progress issues' do
      # Setup
      let(:issues) do
        [
          { 'state' => { 'type' => 'started' } },
          { 'state' => { 'type' => 'started' } },
          { 'state' => { 'type' => 'backlog' } }
        ]
      end

      it 'counts current WIP' do
        expect(result[:current_wip]).to eq(2)
      end
    end

    context 'with completed issues but no startedAt' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-12-01T10:00:00Z',
            'startedAt' => nil,
            'completedAt' => '2024-12-04T10:00:00Z',
            'state' => { 'type' => 'completed' }
          }
        ]
      end

      it 'returns zero cycle time when no startedAt' do
        expect(result[:median_cycle_time_days]).to eq(0)
      end

      it 'still calculates lead time' do
        expect(result[:median_lead_time_days]).to be > 0
      end
    end

    context 'with old completed issues outside weekly window' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-01T10:00:00Z',
            'startedAt' => '2024-11-02T10:00:00Z',
            'completedAt' => '2024-11-20T10:00:00Z',
            'state' => { 'type' => 'completed' }
          }
        ]
      end

      it 'excludes old issues from weekly throughput' do
        expect(result[:weekly_throughput]).to eq(0)
      end

      it 'includes old issues in cycle time calculation' do
        expect(result[:median_cycle_time_days]).to be > 0
      end
    end

    context 'with no issues' do
      # Setup
      let(:issues) { [] }

      it 'returns zero for all metrics', :aggregate_failures do
        expect(result[:median_cycle_time_days]).to eq(0)
        expect(result[:median_lead_time_days]).to eq(0)
        expect(result[:weekly_throughput]).to eq(0)
        expect(result[:current_wip]).to eq(0)
      end
    end
  end

  describe '#to_rows' do
    subject(:rows) { calculator.to_rows }

    # Setup
    let(:issues) { [] }

    it 'returns rows in expected format' do
      expect(rows).to all(match([today.to_s, 'flow', kind_of(String), kind_of(Numeric)]))
    end

    it 'includes all flow metrics' do
      metric_names = rows.map { |r| r[2] }

      expect(metric_names).to include(
        'median_cycle_time_days',
        'median_lead_time_days',
        'weekly_throughput',
        'current_wip'
      )
    end
  end
end
