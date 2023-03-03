# frozen_string_literal: true

# This class describes a change to the project's Dependencies which has been
# determined by a Dependabot operation.
#
# It includes a list of changed Dependabot::Dependency objects, the
# Dependabot::DependencyFile objects which contain the diff to be applied along
# with any Dependabot::GroupRule that was used to generate the change.
#
# This class provides methods for presenting the change set which can be used
# by adapters to create a Pull Request, apply the changes on disk, etc.
module Dependabot
  class DependencyChange
    attr_reader :job, :dependencies, :updated_dependency_files

    def initialize(job:, dependencies:, updated_dependency_files:, group_rule: nil)
      @job = job
      @dependencies = dependencies
      @updated_dependency_files = updated_dependency_files
      @group_rule = group_rule
    end

    def matches_requested_dependency_changes?
      return true if job.dependencies.empty?

      # NOTE: Gradle, Maven and Nuget dependency names can be case-insensitive
      # and the dependency name in the security advisory often doesn't match
      # what users have specified in their manifest.
      dependencies.map(&:name).map(&:downcase) == job.dependencies.map(&:downcase)
    end

    def existing_pull_request
      return @existing_pull_request if defined?(@existing_pull_request)

      @existing_pull_request = job.existing_pull_requests.find { |pr| Set.new(pr) == dependency_change.to_set }
    end

    def to_set
      dependency_set
    end

    def pr_message
      return @pr_message if defined?(@pr_message)

      @pr_message = Dependabot::PullRequestCreator::MessageBuilder.new(
        source: job.source,
        dependencies: dependencies,
        files: updated_dependency_files,
        credentials: job.credentials,
        commit_message_options: job.commit_message_options,
        # This ensures that PR messages we build replace github.com links with
        # a redirect that stop markdown enriching them into mentions on the source
        # repository.
        #
        # TODO: Promote this value to a constant or similar once we have
        # updated core to avoid surprise outcomes if this is unset.
        github_redirection_service: "github-redirect.dependabot.com"
      ).message
    end

    def humanized
      dependencies.map do |dependency|
        "#{dependency.name} ( from #{dependency.previous_version} to #{dependency.version} )"
      end.join(", ")
    end

    private

    def dependency_set
      @dependency_set ||= Set.new(
        dependencies.map do |dep|
          {
            "dependency-name" => dep.name,
            "dependency-version" => dep.version,
            "dependency-removed" => dep.removed? ? true : nil
          }.compact
        end
      )
    end
  end
end
