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
      @stdout, @stderr, @exitcode = read_output_in_chunks(@environment)

      show_debug_command_output
    end

    def success?(exit_code: 0)
      @exitcode == exit_code
    end

    private

    def read_output_in_chunks(environment = {})
      # Courtesy of: https://gist.github.com/chrisn/7450808
      def all_eof(files)
        files.find { |f| !f.eof }.nil?
      end
      block_size = 1024
      final_stdout = ''
      final_stderr = ''
      final_process = nil
      KubernetesHarness.logger.debug("Running #{@command} with env #{environment}")
      Open3.popen3(environment.transform_keys(&:to_s), @command) do |stdin, stdout, stderr, thread|
        stdin.close_write

        begin
          files = [stdout, stderr]
          until all_eof(files)
            ready = IO.select(files)
            next unless ready

            readable = ready[0]
            readable.each do |f|
              data = f.read_nonblock(block_size)
              stdout_chunk = f == stdout ? data : ''
              stderr_chunk = f == stderr ? data : ''
              if f == stdout
                final_stdout += stdout_chunk
              else
                final_stderr += stderr_chunk
              end
              KubernetesHarness.logger.debug("command: #{@command}, stdout_chunk: #{stdout_chunk}")
              KubernetesHarness.logger.debug("command: #{@command}, stderr_chunk: #{stderr_chunk}")
            rescue EOFError
              KubernetesHarness.logger.debug("command: #{@command}, stream has EOF'ed")
            end
          end
        rescue IOError => e
          puts "IOError: #{e}"
        end
        final_process = thread.value.exitstatus
      end

      [final_stdout, final_stderr, final_process]
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
  end
end
