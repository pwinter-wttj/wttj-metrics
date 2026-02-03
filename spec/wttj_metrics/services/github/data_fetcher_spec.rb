# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WttjMetrics::Services::Github::DataFetcher do
  subject(:fetcher) { described_class.new(cache, logger, start_date, end_date) }

  let(:logger) { instance_double(Logger, info: nil, error: nil, warn: nil) }
  let(:client) { instance_double(WttjMetrics::Sources::Github::Client) }
  let(:cache) { instance_double(WttjMetrics::Data::FileCache, read: nil, write: nil) }
  let(:start_date) { Date.today - 90 }
  let(:end_date) { Date.today }
  let(:prs) do
    [{ 'title' => 'PR 1', 'createdAt' => Date.today.iso8601, 'url' => 'http://github.com/owner/repo/pull/1',
       'repository' => { 'name' => 'repo' } }]
  end
  let(:releases) { [{ 'name' => 'v1.0', 'publishedAt' => Date.today.iso8601 }] }
  let(:teams) { { 'Team A' => ['user-a'] } }

  before do
    allow(WttjMetrics::Sources::Github::Client).to receive(:new).and_return(client)
    allow(WttjMetrics::Data::FileCache).to receive(:new).and_return(cache)
    allow(client).to receive_messages(
      fetch_organization_pull_requests: prs,
      fetch_organization_pull_requests_updated_after: prs,
      fetch_releases: releases,
      fetch_teams: teams
    )
    ENV['GITHUB_ORG'] = 'WTTJ'
    ENV['GITHUB_TOKEN'] = 'token'
  end

  after do
    ENV.delete('GITHUB_ORG')
    ENV.delete('GITHUB_TOKEN')
  end

  describe '#call' do
    context 'when fetching pull requests' do
      it 'fetches organization pull requests' do
        result = fetcher.call
        expected_prs = [{ title: 'PR 1', createdAt: Date.today.iso8601, url: 'http://github.com/owner/repo/pull/1',
                          repository: { name: 'repo' } }]
        expect(result[:pull_requests]).to eq(expected_prs)
        expect(client).to have_received(:fetch_organization_pull_requests).with('WTTJ', anything)
      end

      context 'with fresh cache' do
        before do
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 24).and_return(prs)
        end

        it 'returns cached PRs without fetching from client' do
          result = fetcher.call
          expected_prs = [{ title: 'PR 1', createdAt: Date.today.iso8601, url: 'http://github.com/owner/repo/pull/1',
                            repository: { name: 'repo' } }]
          expect(result[:pull_requests]).to eq(expected_prs)
          expect(client).not_to have_received(:fetch_organization_pull_requests)
        end
      end

      context 'with stale cache' do
        let(:cached_prs) do
          [{ 'title' => 'Old PR', 'createdAt' => (Date.today - 10).iso8601, 'updatedAt' => (Date.today - 5).iso8601,
             'url' => 'http://github.com/owner/repo/pull/old', 'repository' => { 'name' => 'repo' } }]
        end
        let(:new_prs) do
          [{ 'title' => 'New PR', 'createdAt' => Date.today.iso8601, 'updatedAt' => Date.today.iso8601,
             'url' => 'http://github.com/owner/repo/pull/new', 'repository' => { 'name' => 'repo' } }]
        end

        before do
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 24).and_return(nil)
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 87_600).and_return(cached_prs)
          allow(client).to receive(:fetch_organization_pull_requests_updated_after).and_return(new_prs)
        end

        it 'merges cached PRs with updates' do
          result = fetcher.call
          expect(result[:pull_requests].size).to eq(2)
          expect(client).to have_received(:fetch_organization_pull_requests_updated_after)
        end
      end

      context 'with stale cache missing updatedAt' do
        let(:cached_prs) do
          [{ 'title' => 'Old PR', 'createdAt' => (Date.today - 10).iso8601,
             'url' => 'http://github.com/owner/repo/pull/old', 'repository' => { 'name' => 'repo' } }]
        end

        before do
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 24).and_return(nil)
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 87_600).and_return(cached_prs)
          allow(client).to receive(:fetch_organization_pull_requests_updated_after).and_return([])
        end

        it 'uses from_date as since_date' do
          fetcher.call
          # Expect fetch with from_date (default 90 days ago)
          expected_date = (Date.today - 90).iso8601
          expect(client).to have_received(:fetch_organization_pull_requests_updated_after).with('WTTJ', expected_date)
        end
      end
    end

    context 'when fetching releases' do
      it 'fetches releases for repositories found in PRs' do
        result = fetcher.call
        expect(result[:releases]).to include(include('repository_name' => 'repo'))
        expect(client).to have_received(:fetch_releases).with('WTTJ/repo', anything)
      end

      context 'with fresh releases cache' do
        before do
          allow(cache).to receive(:read).with('github_releases_WTTJ', max_age_hours: 24).and_return(releases)
        end

        it 'returns cached releases' do
          result = fetcher.call
          expect(result[:releases]).to eq(releases)
          expect(client).not_to have_received(:fetch_releases)
        end
      end
    end

    context 'when PRs have no repository info' do
      let(:prs) do
        [{ 'title' => 'PR 1', 'createdAt' => Date.today.iso8601, 'url' => 'url' }]
      end

      it 'fetches no releases' do
        result = fetcher.call
        expect(result[:releases]).to eq([])
        expect(client).not_to have_received(:fetch_releases)
      end
    end

    context 'when client raises Unauthorized' do
      before do
        allow(client).to receive(:fetch_organization_pull_requests).and_raise(Octokit::Unauthorized)
      end

      it 'returns empty hash' do
        expect(fetcher.call).to eq({})
      end
    end

    context 'when client raises StandardError' do
      before do
        allow(client).to receive(:fetch_organization_pull_requests).and_raise(StandardError.new('Boom'))
      end

      it 'logs error and returns empty hash' do
        expect(fetcher.call).to eq({})
        expect(logger).to have_received(:error).with('❌ Error fetching GitHub data: Boom')
      end
    end

    context 'when fetching teams' do
      it 'fetches teams' do
        result = fetcher.call
        aggregate_failures do
          expect(result[:teams]).to eq(teams)
          expect(client).to have_received(:fetch_teams).with('WTTJ')
          expect(cache).to have_received(:write).with('github_teams_WTTJ', teams)
        end
      end

      context 'when GITHUB_TOKEN is missing but cached teams exist' do
        let(:cached_teams) { { 'Cached Team' => ['user-cached'] } }

        before do
          ENV.delete('GITHUB_TOKEN')
          allow(cache).to receive(:read).with('github_prs_WTTJ', max_age_hours: 24).and_return(prs)
          allow(cache).to receive(:read).with('github_teams_WTTJ', max_age_hours: 24).and_return(nil)
          allow(cache).to receive(:read).with('github_teams_WTTJ', max_age_hours: 87_600).and_return(cached_teams)
        end

        it 'uses cached teams without fetching from client' do
          result = fetcher.call

          aggregate_failures do
            expect(result[:teams]).to eq(cached_teams)
            expect(client).not_to have_received(:fetch_teams)
          end
        end
      end

      it 'handles errors when fetching teams' do
        allow(client).to receive(:fetch_teams).and_raise(StandardError.new('Team error'))
        result = fetcher.call
        expect(result[:teams]).to eq({})
        expect(logger).to have_received(:warn).with(/Error fetching teams: Team error/)
      end
    end

    context 'when GITHUB_ORG is missing' do
      before do
        ENV.delete('GITHUB_ORG')
      end

      it 'returns empty hash and logs error' do
        result = fetcher.call
        expect(result).to eq({})
        expect(logger).to have_received(:error).with(/GITHUB_ORG environment variable is not set/)
      end
    end

    context 'with custom date range' do
      let(:start_date) { Date.today - 30 }
      let(:end_date) { Date.today }

      it 'fetches pull requests from 30 days ago' do
        fetcher.call
        expected_date = (Date.today - 30).iso8601
        expect(client).to have_received(:fetch_organization_pull_requests).with('WTTJ', expected_date)
      end
    end
  end
end
