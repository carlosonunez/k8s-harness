# frozen_string_literal: true

require 'logger'

# KubernetesHarness.
module KubernetesHarness
  @logger = Logger.new($stdout)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  def self.logger
    @logger
  end
end
