# frozen_string_literal: true

require 'yaml'
require 'digest/md5'

module KubernetesHarness
  module Clusters
    # This class provides a handy set of information that might be useful for k8s-harness
    # users after creating their clusters.
    class ClusterInfo
      attr_reader :master_ip_address,
                  :worker_ip_addresses,
                  :docker_registry_address,
                  :ssh_key_path,
                  :kubernetes_cluster_token
      attr_accessor :kubeconfig_path

      IP_ADDRESS_REGEX = /
        \b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.
        (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b
      /x.freeze

      def initialize(master_ip_address_command:,
                     worker_ip_addresses_command:,
                     docker_registry_command:,
                     kubeconfig_path:,
                     ssh_key_path:)
        @kubeconfig_path = kubeconfig_path
        @ssh_key_path = ssh_key_path
        @master_ip_address = get_ip_addresses_from_command(master_ip_address_command).first
        @docker_registry_address = get_ip_addresses_from_command(docker_registry_command).first
        @worker_ip_addresses =
          worker_ip_addresses_command.map do |command|
            get_ip_addresses_from_command(command)
          end.flatten
        @kubernetes_cluster_token = generate_k8s_token(
          @master_ip_address,
          @worker_ip_addresses,
          @docker_registry_address
        )
      end

      def to_yaml
        YAML.dump({
                    master_ip_address: @master_ip_address,
                    worker_ip_addresses: @worker_ip_addresses,
                    docker_registry_address: @docker_registry_address,
                    kubeconfig_path: @kubeconfig_path,
                    ssh_key_path: @ssh_key_path,
                    kubernetes_cluster_token: @kubernetes_cluster_token
                  })
      end

      private

      def generate_k8s_token(master_ip, worker_ip, docker_registry)
        combined_addresses = [master_ip, worker_ip, docker_registry].flatten.join('')
        Digest::MD5.hexdigest(combined_addresses)
      end

      def get_ip_addresses_from_command(command)
        command.execute!
        command.stdout.split("\n").select { |line| line.match? IP_ADDRESS_REGEX }
      end
    end
  end
end
