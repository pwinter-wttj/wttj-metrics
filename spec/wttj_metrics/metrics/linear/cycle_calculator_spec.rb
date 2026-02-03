# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::CycleCalculator do
  subject(:calculator) { described_class.new(cycles, today: today) }

  # Setup
  let(:today) { Date.new(2024, 12, 5) }
  let(:cycles) { [] }

  describe '#calculate' do
    subject(:result) { calculator.calculate }

    context 'with active cycle' do
      # Setup
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-12-01',
            'endsAt' => '2024-12-14',
            'issues' => {
              'nodes' => [
                { 'estimate' => 3, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 5, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 2, 'state' => { 'type' => 'started' } }
              ]
            }
          }
        ]
      end

      it 'calculates median cycle velocity from completed cycles' do
        # No completed cycles in this test, so median should be 0
        expect(result[:median_cycle_velocity]).to eq(0)
      end
    end

    context 'with completed cycles' do
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-11-01',
            'endsAt' => '2024-11-14',
            'completedAt' => '2024-11-14T10:00:00Z',
            'issues' => {
              'nodes' => [
                { 'estimate' => 3, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 5, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 2, 'state' => { 'type' => 'started' } }
              ]
            }
          },
          {
            'name' => 'Sprint 2',
            'startsAt' => '2024-11-15',
            'endsAt' => '2024-11-28',
            'completedAt' => '2024-11-28T10:00:00Z',
            'issues' => {
              'nodes' => [
                { 'estimate' => 2, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 3, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 5, 'state' => { 'type' => 'completed' } },
                { 'estimate' => 1, 'state' => { 'type' => 'completed' } }
              ]
            }
          },
          {
            'name' => 'Sprint 3',
            'startsAt' => '2024-11-29',
            'endsAt' => '2024-12-12',
            'completedAt' => '2024-12-12T10:00:00Z',
            'issues' => {
              'nodes' => [
                { 'estimate' => nil, 'state' => { 'type' => 'completed' } },
                { 'estimate' => nil, 'state' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      it 'calculates median cycle velocity across completed cycles' do
        # Sprint 1: 3 + 5 = 8 points
        # Sprint 2: 2 + 3 + 5 + 1 = 11 points
        # Sprint 3: no estimates => 0 points (excluded from median)
        # Median (excluding zeros): median(8, 11) = 9.5 points
        expect(result[:median_cycle_velocity]).to eq(9.5)
      end

      it 'calculates median commitment accuracy across completed cycles' do
        # Sprint 1: 2/3 = 66.67%
        # Sprint 2: 4/4 = 100%
        # Sprint 3: 2/2 = 100%
        # Median(66.67, 100, 100) = 100%
        expect(result[:cycle_commitment_accuracy]).to eq(100.0)
      end
    end

    context 'with completed cycle' do
      # Setup
      let(:cycles) do
        [
          {
            'name' => 'Sprint 0',
            'startsAt' => '2024-11-15',
            'endsAt' => '2024-11-30',
            'completedAt' => '2024-11-30T10:00:00Z',
            'issues' => { 'nodes' => [] },
            'uncompletedIssuesUponClose' => {
              'nodes' => [{ 'id' => '1' }, { 'id' => '2' }]
            }
          }
        ]
      end

      it 'calculates average carryover count across completed cycles' do
        expect(result[:cycle_carryover_count]).to eq(2.0)
      end
    end

    context 'with multiple completed cycles' do
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-10-01',
            'endsAt' => '2024-10-14',
            'completedAt' => '2024-10-14T10:00:00Z',
            'issues' => { 'nodes' => [] },
            'uncompletedIssuesUponClose' => {
              'nodes' => [{ 'id' => '1' }, { 'id' => '2' }, { 'id' => '3' }]
            }
          },
          {
            'name' => 'Sprint 2',
            'startsAt' => '2024-10-15',
            'endsAt' => '2024-10-28',
            'completedAt' => '2024-10-28T10:00:00Z',
            'issues' => { 'nodes' => [] },
            'uncompletedIssuesUponClose' => {
              'nodes' => [{ 'id' => '4' }]
            }
          },
          {
            'name' => 'Sprint 3',
            'startsAt' => '2024-10-29',
            'endsAt' => '2024-11-11',
            'completedAt' => '2024-11-11T10:00:00Z',
            'issues' => { 'nodes' => [] },
            'uncompletedIssuesUponClose' => {
              'nodes' => [{ 'id' => '5' }, { 'id' => '6' }, { 'id' => '7' }, { 'id' => '8' }]
            }
          }
        ]
      end

      it 'calculates median carryover across all completed cycles' do
        # Median(3, 1, 4) = 3
        expect(result[:cycle_carryover_count]).to eq(3.0)
      end
    end

    context 'with completed cycle but no issues' do
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-12-01',
            'endsAt' => '2024-12-14',
            'completedAt' => '2024-12-14T10:00:00Z',
            'issues' => { 'nodes' => [] }
          }
        ]
      end

      it 'returns zero for commitment accuracy' do
        expect(result[:cycle_commitment_accuracy]).to eq(0)
      end
    end

    context 'with issues but no estimate' do
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-12-01',
            'endsAt' => '2024-12-14',
            'completedAt' => '2024-12-14T10:00:00Z',
            'issues' => {
              'nodes' => [
                { 'estimate' => nil, 'state' => { 'type' => 'completed' } }
              ]
            }
          }
        ]
      end

      it 'returns zero when all completed cycles have zero velocity' do
        expect(result[:median_cycle_velocity]).to eq(0)
      end
    end

    context 'with no completed cycles' do
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'startsAt' => '2024-12-01',
            'endsAt' => '2024-12-14',
            'completedAt' => nil,
            'issues' => { 'nodes' => [] }
          }
        ]
      end

      it 'returns zero for carryover and commitment accuracy' do
        expect(result[:cycle_carryover_count]).to eq(0)
        expect(result[:cycle_commitment_accuracy]).to eq(0)
      end
    end

    context 'with no cycles' do
      # Setup
      let(:cycles) { [] }

      it 'returns zero for all metrics', :aggregate_failures do
        expect(result[:median_cycle_velocity]).to eq(0)
        expect(result[:cycle_commitment_accuracy]).to eq(0)
        expect(result[:cycle_carryover_count]).to eq(0)
      end
    end
  end

  describe '#to_rows' do
    subject(:rows) { calculator.to_rows }

    context 'with cycles' do
      # Setup
      let(:cycles) do
        [
          {
            'name' => 'Sprint 1',
            'number' => 1,
            'startsAt' => '2024-12-01',
            'endsAt' => '2024-12-14',
            'progress' => 0.5,
            'team' => { 'name' => 'Team A' },
            'issues' => {
              'nodes' => [
                { 'estimate' => 3, 'state' => { 'type' => 'completed' }, 'assignee' => { 'id' => 'u1' } }
              ]
            },
            'uncompletedIssuesUponClose' => { 'nodes' => [] }
          }
        ]
      end

      it 'includes cycle metrics rows' do
        cycle_metrics = rows.select { |r| r[1] == 'cycle_metrics' }

        expect(cycle_metrics.map { |r| r[2] }).to include(
          'median_cycle_velocity',
          'cycle_commitment_accuracy',
          'cycle_carryover_count'
        )
      end

      it 'includes cycle detail rows', :aggregate_failures do
        cycle_details = rows.select { |r| r[1] == 'cycle' }

        expect(cycle_details).not_to be_empty
        expect(cycle_details.first[2]).to start_with('Team A:Sprint 1:')
      end
    end
  end
end
