module Travis
  module Addons
    module GithubStatus

      # Adds a comment with a build notification to the pull-request the request
      # belongs to.
      class EventHandler < Event::Handler
        API_VERSION = 'v2'
        EVENTS = /build:(started|finished)/

        def handle?
          unless tokens.any?
            error "No GitHub OAuth tokens found for #{object.repository.slugs}"
          end

          tokens.any?
        end

        def handle
          Travis::Addons::GithubStatus::Task.run(:github_status, payload, tokens: tokens)
        end

        private

          def tokens
            @tokens ||= users.map { |user| { user.login => user.github_oauth_token } }.inject(:merge)
          end

          def users
            @users ||= [
              build_committer,
              admin,
              users_with_push_access,
            ].flatten.compact
          end

          def build_committer
            user = User.with_email(object.commit.committer_email)
            user if user && user.permission?(repository_id: object.repository.id, push: true)
          end

          def admin
            @admin ||= Travis.run_service(:find_admin, repository: object.repository)
          rescue Travis::AdminMissing
            nil
          end

          def users_with_push_access
            User.with_github_token.with_permissions(repository_id: object.repository.id, push: true).all
          end

          Instruments::EventHandler.attach_to(self)
      end
    end
  end
end

