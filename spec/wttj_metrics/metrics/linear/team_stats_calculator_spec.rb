# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::TeamStatsCalculator do
  subject(:calculator) { described_class.new(cycles_by_team) }

  # Setup
  let(:cycles_by_team) { {} }

  describe '#calculate' do
    subject(:result) { calculator.calculate }

    context 'with cycles from multiple teams' do
      # Setup
      let(:cycles_by_team) do
        {
          'Team A' => [
            {
              status: 'completed',
              total_issues: 10,
              velocity: 20,
              completed_issues: 8,
              assignee_count: 3,
              completion_rate: 80.0,
              tickets_per_day: 0.8,
              carryover: 2
            },
            {
              status: 'completed',
              total_issues: 12,
              velocity: 30,
              completed_issues: 10,
              assignee_count: 4,
              completion_rate: 83.3,
              tickets_per_day: 1.0,
              carryover: 2
            }
          ],
          'Team B' => [
            {
              status: 'active',
              total_issues: 8,
              velocity: 15,
              completed_issues: 5,
              assignee_count: 2,
              completion_rate: 62.5,
              tickets_per_day: 0.5,
              carryover: 3
            }
          ]
        }
      end

      it 'returns stats for each team' do
        expect(result.keys).to contain_exactly('Team A', 'Team B')
      end

      it 'calculates Team A medians correctly', :aggregate_failures do
        team_a = result['Team A']

        expect(team_a[:total_cycles]).to eq(2)
        expect(team_a[:cycles_with_data]).to eq(2)
        expect(team_a[:median_velocity]).to eq(25)
        expect(team_a[:median_tickets_per_cycle]).to eq(9)
        expect(team_a[:median_assignees]).to eq(4)
        expect(team_a[:total_carryover]).to eq(4)
      end

      it 'calculates Team B stats correctly', :aggregate_failures do
        team_b = result['Team B']

        expect(team_b[:total_cycles]).to eq(1)
        expect(team_b[:median_velocity]).to eq(15.0)
      end
    end

    context 'with no cycles' do
      # Setup
      let(:cycles_by_team) { {} }

      it 'returns empty hash' do
        expect(result).to eq({})
      end
    end

    context 'with cycles having zero issues' do
      # Setup
      let(:cycles_by_team) do
        {
          'Team A' => [
            { status: 'completed', total_issues: 0, velocity: 0 },
            { status: 'completed', total_issues: 5, velocity: 10, completed_issues: 5 }
          ]
        }
      end

      it 'excludes cycles with zero issues from medians' do
        expect(result['Team A'][:cycles_with_data]).to eq(1)
      end
    end

    context 'with non-active cycles' do
      # Setup
      let(:cycles_by_team) do
        {
          'Team A' => [
            { status: 'planned', total_issues: 10, velocity: 20 }
          ]
        }
      end

      it 'excludes planned cycles from calculations' do
        expect(result['Team A'][:cycles_with_data]).to eq(0)
      end
    end
  end
end
