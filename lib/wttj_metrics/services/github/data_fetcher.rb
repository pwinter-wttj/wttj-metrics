# frozen_string_literal: true

require 'ruby-progressbar'

module WttjMetrics
  module Services
    module Github
      class DataFetcher
        def initialize(cache, logger, start_date = nil, end_date = nil)
          @cache = cache
          @logger = logger
          @start_date = start_date || (Date.today - 90)
          @end_date = end_date || Date.today
        end

        def call
          @logger.info '📊 Fetching data from GitHub...'

          from_date = @start_date.iso8601
          prs = fetch_prs(from_date)
          return {} if prs.empty?

          filtered_prs = filter_prs(prs, from_date)

          @logger.info "   Found #{filtered_prs.size} pull requests (created >= #{from_date})"

          releases = fetch_releases_data(filtered_prs, from_date)
          @logger.info "   Found #{releases.size} releases"

          teams = fetch_teams_data
          @logger.info "   Found #{teams.size} teams" unless teams.empty?

          { pull_requests: filtered_prs, releases: releases, teams: teams }
        rescue Octokit::Unauthorized
          # Already logged in client
          {}
        rescue StandardError => e
          @logger.error "❌ Error fetching GitHub data: #{e.message}"
          {}
        end

        private

        def fetch_prs(from_date)
          if ENV['GITHUB_ORG']
            fetch_org_prs(ENV['GITHUB_ORG'], from_date)
          else
            @logger.error '❌ GITHUB_ORG environment variable is not set'
            []
          end
        end

        def fetch_org_prs(org, from_date)
          @logger.info "   Fetching for organization: #{org}"
          cache_key = "github_prs_#{org}"

          # Try fresh cache first (1 day TTL)
          if cache
            fresh_prs = cache.read(cache_key, max_age_hours: 24)
            if fresh_prs
              @logger.info '   ✨ Cache is fresh (< 24h). Skipping update.'
              return fresh_prs
            end
            cached_prs = cache.read(cache_key, max_age_hours: 87_600) || []
          else
            cached_prs = []
          end

          if cached_prs.any? && !github_token?
            @logger.warn '   ⚠️  GITHUB_TOKEN not set. Using cached PRs without updating.'
            return cached_prs
          end

          prs = if cached_prs.any?
                  begin
                    merge_with_cache(org, cached_prs, from_date)
                  rescue Octokit::Unauthorized => e
                    @logger.warn "   ⚠️  Cannot update PR cache (unauthorized): #{e.message}. Using cached PRs."
                    cached_prs
                  rescue StandardError => e
                    @logger.warn "   ⚠️  Cannot update PR cache: #{e.message}. Using cached PRs."
                    cached_prs
                  end
                else
                  unless github_token?
                    @logger.error '   ❌ No cached PRs and GITHUB_TOKEN not set. Cannot fetch PRs.'
                    return []
                  end

                  @logger.info "   No cache found. Fetching all PRs since #{from_date}..."
                  prs = client.fetch_organization_pull_requests(org, from_date)
                  deep_stringify_keys(prs)
                end

          cache&.write(cache_key, prs)
          prs
        end

        def merge_with_cache(org, cached_prs, from_date)
          latest_update = cached_prs.filter_map { |pr| pr['updatedAt'] }.max
          since_date = latest_update || from_date

          @logger.info "   Found #{cached_prs.size} cached PRs. Fetching updates since #{Date.parse(since_date)}..."
          new_prs = client.fetch_organization_pull_requests_updated_after(org, since_date)
          new_prs = deep_stringify_keys(new_prs)

          pr_map = cached_prs.to_h { |pr| [pr['url'], pr] }
          new_prs.each { |pr| pr_map[pr['url']] = pr }

          pr_map.values
        end

        def filter_prs(prs, from_date)
          to_date = (@end_date + 1).iso8601
          filtered = prs.select do |pr|
            pr['createdAt'] >= from_date && pr['createdAt'] < to_date
          end
          filtered.map { |pr| deep_symbolize_keys(pr) }
        end

        def fetch_releases_data(prs, from_date)
          cache_key = "github_releases_#{ENV.fetch('GITHUB_ORG', nil)}"
          stale_releases = cache&.read(cache_key, max_age_hours: 87_600)
          if cache
            fresh_releases = cache.read(cache_key, max_age_hours: 24)
            if fresh_releases
              @logger.info '   ✨ Releases cache is fresh (< 24h). Skipping update.'
              return fresh_releases
            end
          end

          if stale_releases && !github_token?
            @logger.warn '   ⚠️  GITHUB_TOKEN not set. Using cached releases without updating.'
            return stale_releases
          end

          repos = Set.new

          prs.each do |pr|
            # Handle both symbol and string keys since filter_prs might have symbolized them
            repo_name = pr.dig(:repository, :name) || pr.dig('repository', 'name')
            repos.add("#{ENV.fetch('GITHUB_ORG', nil)}/#{repo_name}") if repo_name
          end

          return [] if repos.empty?

          unless github_token?
            @logger.warn '   ⚠️  GITHUB_TOKEN not set and no cached releases. Skipping releases fetch.'
            return []
          end

          @logger.info "   Fetching releases for #{repos.size} repositories..."

          progress_bar = ProgressBar.create(
            title: 'Releases',
            total: repos.size,
            format: '%t: |%B| %p%% %e'
          )

          all_releases = []
          repos.each do |repo|
            releases = client.fetch_releases(repo, from_date)
            releases = deep_stringify_keys(releases)

            repo_name = repo.split('/').last
            releases.each { |r| r['repository_name'] = repo_name }

            all_releases.concat(releases)
            progress_bar.increment
          end
          progress_bar.finish

          cache&.write(cache_key, all_releases)

          all_releases
        end

        def fetch_teams_data
          org = ENV.fetch('GITHUB_ORG', nil)
          cache_key = "github_teams_#{org}"
          stale_teams = nil

          if cache
            fresh_teams = cache.read(cache_key, max_age_hours: 24)
            return fresh_teams if fresh_teams

            stale_teams = cache.read(cache_key, max_age_hours: 87_600)
          end

          unless github_token?
            if stale_teams
              @logger.warn '   ⚠️  GITHUB_TOKEN not set. Using cached teams without updating.'
              return stale_teams
            end

            @logger.warn '   ⚠️  GITHUB_TOKEN not set and no cached teams. Skipping teams fetch.'
            return {}
          end

          @logger.info "   Fetching teams for organization: #{org}"
          teams = client.fetch_teams(org)
          cache&.write(cache_key, teams)
          teams
        rescue StandardError => e
          @logger.warn "⚠️  Error fetching teams: #{e.message}"
          stale_teams || {}
        end

        def github_token?
          !ENV.fetch('GITHUB_TOKEN', nil).to_s.strip.empty?
        end

        def client
          @client ||= Sources::Github::Client.new(logger: @logger)
        end

        attr_reader :cache

        def deep_stringify_keys(obj)
          case obj
          when Array
            obj.map { |v| deep_stringify_keys(v) }
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              result[k.to_s] = deep_stringify_keys(v)
            end
          else
            obj
          end
        end

        def deep_symbolize_keys(obj)
          case obj
          when Array
            obj.map { |v| deep_symbolize_keys(v) }
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              result[k.to_sym] = deep_symbolize_keys(v)
            end
          else
            obj
          end
        end
      end
    end
  end
end
