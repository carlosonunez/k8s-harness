# frozen_string_literal: true

require 'k8s_harness/clusters'
require 'k8s_harness/clusters/cluster_info'
require 'k8s_harness/harness_file'

module KubernetesHarness
  # All entrypoints for our subcommands live here.
  module Subcommand
    def self.run(options = {})
      return true if !options.nil? && options[:show_usage]

      KubernetesHarness.nice_logger.info(
        'Creating your cluster now. This might take a few minutes.'
      )
      cluster_info = KubernetesHarness::Clusters.create!
      KubernetesHarness.logger.info("Master address: #{cluster_info.master_ip_address}")
      KubernetesHarness.logger.info("Worker address: #{cluster_info.worker_ip_addresses}")
      KubernetesHarness.logger.info("Kubeconfig path: #{cluster_info.kubeconfig_path}")
      KubernetesHarness.logger.info("SSH key path: #{cluster_info.ssh_key_path}")
    end

    def self.validate(options = {})
      return true if !options.nil? && options[:show_usage]

      KubernetesHarness::HarnessFile.validate
    end
  end
end
