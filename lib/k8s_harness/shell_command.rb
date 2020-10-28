# frozen_string_literal: true

require 'English'
require 'open3'

module KubernetesHarness
  # Handles all interactions with shells
  class ShellCommand
    attr_accessor :command, :stdout, :stderr

    # Ruby 2.7 deprecated keyword arguments in favor of passing in Hashes.
    # TODO: Refactor to account for this.
    def initialize(command, environment: {})
      KubernetesHarness.logger.debug("Creating new command #{command} with env #{environment}")
      @command = command
      @environment = environment
      @exitcode = nil
      @stdout = nil
      @stderr = nil
    end

    def execute!
      KubernetesHarness.logger.debug("Running #{@command} with env #{@environment}")
      if @environment.empty?
        @stdout, @stderr, process = Open3.capture3(@command)
      else
        @stdout, @stderr, process = Open3.capture3(@environment.transform_keys(&:to_s), @command)
      end
      @exitcode = process.exitstatus
      show_debug_command_output
    end

    def show_debug_command_output
      message = <<~MESSAGE.strip
        Running #{@command} done, \
        rc = #{@exitcode}, \
        stdout = '#{@stdout}', \
        stderr = '#{@stderr}'
      MESSAGE
      KubernetesHarness.logger.debug message
    end

    def success?(exit_code: 0)
      @exitcode == exit_code
    end
  end
end
