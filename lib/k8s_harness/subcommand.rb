# frozen_string_literal: true

require 'k8s_harness/clusters'
require 'k8s_harness/clusters/cluster_info'
require 'k8s_harness/clusters/metadata'
require 'k8s_harness/harness_file'

module KubernetesHarness
  # All entrypoints for our subcommands live here.
  module Subcommand
    def self.run(options = {})
      fail_if_validate_fails!(options)
      disable_teardown = !options.nil? && options[:disable_teardown]
      return true if !options.nil? && options[:show_usage]

      print_warning_if_teardown_disabled(disable_teardown)
      cluster_info = create!
      provision!(cluster_info)
      print_post_create_message(cluster_info)
      setup!(options)
      run_tests!(options)
      teardown!(options)
      destroy_cluster!(disable_teardown)
    end

    def self.validate(options = {})
      return true if options.to_h[:show_usage]

      KubernetesHarness::HarnessFile.validate(options)
    end

    def self.destroy(options = {})
      return true if options.to_h[:show_usage]

      KubernetesHarness.nice_logger.info('Destroying your cluster (if any found).')
      KubernetesHarness::Clusters.destroy_existing!
    end

    def self.print_warning_if_teardown_disabled(teardown_flag)
      return unless teardown_flag

      KubernetesHarness.nice_logger.warn(
        <<~MESSAGE.strip
          Teardown is disabled. Your cluster will stay up until you run \
          'k8s-harness destroy'.
        MESSAGE
      )
    end

    def self.create!
      KubernetesHarness.nice_logger.info(
        'Creating your cluster now. Provisioning will occur in a few minutes.'
      )
      KubernetesHarness::Clusters.create!
    end

    def self.provision!(cluster_info)
      KubernetesHarness.nice_logger.info('Provisioning the cluster. This will take a few minutes.')
      KubernetesHarness::Clusters.provision!(cluster_info)
    end

    def self.setup!(options)
      KubernetesHarness::HarnessFile.execute_setup!(options)
    end

    def self.run_tests!(options)
      KubernetesHarness.nice_logger.info('Running your tests.')
      KubernetesHarness::HarnessFile.execute_tests!(options)
    end

    def self.teardown!(options)
      KubernetesHarness::HarnessFile.execute_teardown!(options)
    end

    def self.destroy_cluster!(disable_teardown)
      KubernetesHarness.nice_logger.info('Done. Tearing down the cluster.')
      KubernetesHarness::Clusters.teardown! unless disable_teardown
    end

    def self.fail_if_validate_fails!(options)
      _ = KubernetesHarness::HarnessFile.render(options)
    end

    def self.print_post_create_message(cluster_info)
      # TODO: Make this not hardcoded.
      cluster_info_yaml_path = File.join Clusters::Metadata.default_dir, 'cluster.yaml'
      KubernetesHarness.nice_logger.info(
        <<~MESSAGE.strip
          Cluster has been created. Details are below and in YAML at #{cluster_info_yaml_path}:

              * Master address: '#{cluster_info.master_ip_address}'
              * Worker addresses: #{cluster_info.worker_ip_addresses}
              * Docker registry address: '#{cluster_info.docker_registry_address}'
              * Kubeconfig path: #{cluster_info.kubeconfig_path}
              * SSH key path: #{cluster_info.ssh_key_path}
        MESSAGE
      )
    end
  end
end
