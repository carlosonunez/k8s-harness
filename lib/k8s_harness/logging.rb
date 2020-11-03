# frozen_string_literal: true

require 'logger'

# KubernetesHarness.
module KubernetesHarness
  @logger = Logger.new($stdout)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  @nice_logger = Logger.new($stdout)
  @nice_logger.formatter = proc do |_sev, datetime, _app, message|
    if @logger.level == Logger::DEBUG
      "--> [#{datetime.strftime('%F %T %z')}] #{message}\n"
    else
      "--> #{message}\n"
    end
  end
  def self.logger
    @logger
  end

  def self.nice_logger
    @nice_logger
  end

  # Functions to manipulate log control.
  module Logging
    def self.enable_debug_logging
      KubernetesHarness.logger.level = Logger::DEBUG
    end
  end
end
