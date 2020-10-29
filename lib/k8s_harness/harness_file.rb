# frozen_string_literal: true

require 'shellwords'
require 'yaml'
require 'k8s_harness/shell_command'

module KubernetesHarness
  # This module handles reading and validating .k8sharness files.
  module HarnessFile
    def self.execute_setup!(options)
      exec_command!(options, :setup, 'Setting up your tests.')
    end

    # TODO: Tests missing (but execute_setup! has a test and implementation is the same.)
    def self.execute_tests!(options)
      exec_command!(options, :test, 'Running your tests.')
    end

    # TODO: Tests missing (but execute_setup! has a test and implementation is the same.)
    def self.execute_teardown!(options)
      exec_command!(options, :teardown, 'Tearing down your test bench.')
    end

    def self.exec_command!(options, key, message)
      rendered = render(options)
      raise 'No tests found' if (key == :test) && !rendered.key?(:test)

      KubernetesHarness.logger.debug "Checking for: #{key}"
      return nil unless rendered.key? key

      KubernetesHarness.nice_logger.info message
      command = KubernetesHarness::ShellCommand.new(rendered[key])
      command.execute!
      KubernetesHarness.logger.error command.stderr unless command.stderr.empty?
      puts command.stdout
    end

    def self.test_present?(options)
      harness_file(options).key? :test
    end

    def self.convert_to_commands(options)
      # TODO: Currently, we are assuming that the steps provided in the .k8sharness
      # will always be invoked in a shell.
      # First, we shouldn't assume that the user will want to use `sh` for these commands.
      # Second, we should allow users to invoke code in the language of their preference to
      # maximize codebase homogeneity.
      rendered = harness_file(options)
      rendered.each_key do |key|
        if rendered[key].match?(/.(sh|bash|zsh)$/)
          rendered[key] = "sh #{rendered[key]}"
        else
          rendered[key] = "sh -c '#{Shellwords.escape(rendered[key])}'" \
            unless rendered[key].match?(/^(sh|bash|zsh) -c/)
        end
      end
    end

    def self.render(options = {})
      fp = harness_file_path(options)
      raise "k8s-harness file not found at: #{fp}" unless File.exist? fp
      return convert_to_commands(options) if test_present?(options)

      raise KeyError, <<~MESSAGE.strip
        It appears that your test isn't defined in #{fp}. Ensure that \
        a key called 'test' is in #{fp}. See .k8sharness.example for \
        an example of what a valid .k8sharness looks like.
      MESSAGE
    end

    def self.validate(options)
      puts YAML.dump(render(options.to_h))
    end

    def self.default_harness_file_path
      "#{Dir.pwd}/.k8sharness"
    end

    def self.harness_file_path(options)
      if !options.nil? && options.key?(:alternate_harnessfile)
        options[:alternate_harnessfile]
      else
        default_harness_file_path
      end
    end

    def self.harness_file(options)
      YAML.safe_load(File.read(harness_file_path(options)), symbolize_names: true)
    end
  end
end
