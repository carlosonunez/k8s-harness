# frozen_string_literal: true

require 'k8s_harness/shell_command'

module KubernetesHarness
  module Clusters
    # This module ensures that we have the software we need to run k8s-harness
    # on the user's machine.
    module RequiredSoftware
      def self.software
        {
          vagrant: {
            program_name: 'vagrant',
            version_check: 'vagrant --version'
          }
        }
      end

      def self.installed?
        missing = []
        software.each_key do |app|
          command = KubernetesHarness::ShellCommand.new(software[app][:version_check])
          command.execute!
          missing.push software[app][:program_name] unless command.success?
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
