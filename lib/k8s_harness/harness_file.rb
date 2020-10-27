# frozen_string_literal: true

require 'shellwords'
require 'yaml'

module KubernetesHarness
  # This module handles reading and validating .k8sharness files.
  module HarnessFile
    def self.default_harness_file_path
      "#{Dir.pwd}/.k8sharness"
    end

    def self.harness_file_path(options)
      if options.key? :alternate_harnessfile
        options[:alternate_harnessfile]
      else
        default_harness_file_path
      end
    end

    def self.test_present?(harness_file)
      harness_file.key? :test
    end

    def self.convert_to_commands(harness_file)
      # TODO: Currently, we are assuming that the steps provided in the .k8sharness
      # will always be invoked in a shell.
      # First, we shouldn't assume that the user will want to use `sh` for these commands.
      # Second, we should allow users to invoke code in the language of their preference to
      # maximize codebase homogeneity.
      harness_file.each_key do |key|
        if harness_file[key].match?(/.(sh|bash|zsh)$/)
          harness_file[key] = "sh #{harness_file[key]}"
        else
          harness_file[key] = "sh -c '#{Shellwords.escape(harness_file[key])}'" \
            unless harness_file[key].match?(/^(sh|bash|zsh) -c/)
        end
      end
    end

    def self.render(options = {})
      harness_fp = harness_file_path(options)
      raise "k8s-harness file not found at: #{harness_fp}" unless File.exist? harness_fp

      harness_file = YAML.safe_load(File.read(harness_fp), symbolize_names: true)
      return convert_to_commands(harness_file) if test_present?(harness_file)

      raise KeyError, <<~MESSAGE.strip
        It appears that your test isn't defined in #{harness_fp}. Ensure that \
        a key called 'test' is in #{harness_fp}. See .k8sharness.example for \
        an example of what a valid .k8sharness looks like.
      MESSAGE
    end

    def self.validate(_options = {})
      true
    end
  end
end
