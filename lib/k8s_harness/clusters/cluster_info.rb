# frozen_string_literal: true

module KubernetesHarness
  module Clusters
    # This class provides a handy set of information that might be useful for k8s-harness
    # users after creating their clusters.
    class ClusterInfo
      attr_reader :master_ip_address, :worker_ip_addresses, :kubeconfig_path, :ssh_key_path

      IP_ADDRESS_REGEX = /
        \b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b
      /x.freeze

      def initialize(master_ip_address_command:,
                     worker_ip_addresses_command:,
                     kubeconfig_path:,
                     ssh_key_path:)
        @kubeconfig_path = kubeconfig_path
        @ssh_key_path = ssh_key_path
        @master_ip_address = get_ip_addresses_from_command(master_ip_address_command).first
        @worker_ip_addresses =
          worker_ip_addresses_command.map do |command|
            get_ip_addresses_from_command(command)
          end.flatten
      end

      private

      def get_ip_addresses_from_command(command)
        command.execute!
        command.stdout.split("\n").select { |line| line.match? IP_ADDRESS_REGEX }
      end
    end
  end
end
