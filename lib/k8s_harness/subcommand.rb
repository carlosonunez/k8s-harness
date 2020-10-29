# frozen_string_literal: true

require 'k8s_harness/clusters'
require 'k8s_harness/clusters/cluster_info'
require 'k8s_harness/clusters/metadata'
require 'k8s_harness/harness_file'

module KubernetesHarness
  # All entrypoints for our subcommands live here.
  module Subcommand
    def self.run(options = {})
      return true if !options.nil? && options[:show_usage]

      KubernetesHarness.nice_logger.info(
        'Creating your cluster now. It will be ready in a few minutes.'
      )
      cluster_info = KubernetesHarness::Clusters.create!
      print_post_create_message(cluster_info)
      KubernetesHarness::Clusters.provision!(cluster_info)
    end

    def self.validate(options = {})
      return true if !options.nil? && options[:show_usage]

      KubernetesHarness::HarnessFile.validate
    end

    def self.print_post_create_message(cluster_info)
      # TODO: Make this not hardcoded.
      cluster_info_yaml_path = File.join Clusters::Metadata.default_dir, 'cluster.yaml'
      KubernetesHarness.nice_logger.info(
        <<~MESSAGE.strip
          Cluster has been created. Details are below and in YAML at #{cluster_info_yaml_path}:
        MESSAGE
      )
      KubernetesHarness.nice_logger.info("  Master address: '#{cluster_info.master_ip_address}'")
      KubernetesHarness.nice_logger.info("  Worker addresses: #{cluster_info.worker_ip_addresses}")
      KubernetesHarness.nice_logger.info("  Kubeconfig path: #{cluster_info.kubeconfig_path}")
      KubernetesHarness.nice_logger.info("  SSH key path: #{cluster_info.ssh_key_path}")
    end
  end
end
