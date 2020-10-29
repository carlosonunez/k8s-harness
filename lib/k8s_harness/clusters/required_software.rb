# frozen_string_literal: true

require 'yaml'
require 'k8s_harness/paths'
require 'k8s_harness/shell_command'

module KubernetesHarness
  module Clusters
    # This module ensures that we have the software we need to run k8s-harness
    # on the user's machine.
    module RequiredSoftware
      def self.software
        YAML.safe_load(
          File.read(File.join(KubernetesHarness::Paths.conf_dir, 'required_software.yaml')),
          symbolize_names: true
        )
      end

      def self.ensure_installed_or_exit!
        missing = []
        software.each do |app_data|
          name = app_data[:name]
          version_check = app_data[:version_check]
          KubernetesHarness.logger.debug("Checking that this is installed: #{name}")
          command_string = "sh -c '#{version_check}; exit $?'"
          command = KubernetesHarness::ShellCommand.new(command_string)
          command.execute!
          missing.push name unless command.success?
        end

        raise show_missing_software_message(missing) unless missing.empty?
      end

      def self.show_missing_software_message(apps)
        <<~MESSAGE.strip
          You are missing the following software:

          #{apps.map { |app| "- #{app}" }.join("\n")}

          Please consult the README to learn what you'll need to install before using k8s-harness.
        MESSAGE
      end

      private_class_method :show_missing_software_message
    end
  end
end
