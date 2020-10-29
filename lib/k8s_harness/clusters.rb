# frozen_string_literal: true

require 'k8s_harness/clusters/ansible'
require 'k8s_harness/clusters/constants'
require 'k8s_harness/clusters/cluster_info'
require 'k8s_harness/clusters/metadata'
require 'k8s_harness/clusters/required_software'
require 'k8s_harness/clusters/vagrant'
require 'k8s_harness/shell_command'

module KubernetesHarness
  # Handles bring up and deletion of disposable clusters.
  module Clusters
    def self.create!
      RequiredSoftware.ensure_installed_or_exit!
      Metadata.initialize!
      vagrant_up_disposable_cluster_or_exit!
      cluster = ClusterInfo.new(master_ip_address_command: master_ip_address_command,
                                worker_ip_addresses_command: worker_ip_addresses_command,
                                docker_registry_command: docker_registry_command,
                                kubeconfig_path: cluster_kubeconfig,
                                ssh_key_path: cluster_ssh_key)
      Metadata.write!('cluster.yaml', cluster.to_yaml)
      cluster
    end

    def self.provision!(cluster_info)
      all_results = provision_nodes_in_parallel!(cluster_info)
      failed_results = all_results.filter { |thread| !thread.success? }
      raise 'One or more Ansible runs failed; see logs for more info' unless failed_results.empty?

      true
    end

    def self.provision_nodes_in_parallel!(cluster_info)
      ansible_threads = []
      ssh_key_path = cluster_info.ssh_key_path
      [cluster_info.master_ip_address,
       cluster_info.worker_ip_addresses,
       cluster_info.docker_registry_address].flatten.each do |addr|
        ansible_threads << Thread.new do
          command = Ansible::Playbook.create_run_against_single_host(
            playbook_fp: playbook_path,
            ssh_key_path: ssh_key_path,
            inventory_fp: inventory_path,
            ip_address: addr,
            extra_vars: ["k3s_token=#{cluster_info.kubernetes_cluster_token}"]
          )
          command.execute!
          command
        end
      end
      ansible_threads.each(&:join).map(&:value)
    end

    def self.worker_ip_addresses_command
      Constants::WORKER_NODE_NAMES.map do |node|
        Vagrant.create_and_execute_new_ssh_command(node, Constants::IP_ETH1_COMMAND)
      end
    end

    def self.master_ip_address_command
      Vagrant.create_and_execute_new_ssh_command(Constants::MASTER_NODE_NAME,
                                                 Constants::IP_ETH1_COMMAND)
    end

    def self.docker_registry_command
      Vagrant.create_and_execute_new_ssh_command(Constants::DOCKER_REGISTRY_NAME,
                                                 Constants::IP_ETH1_COMMAND)
    end

    def self.cluster_kubeconfig
      args = [
        '-c',
        '"cat /etc/rancher/k3s/k3s.yaml"',
        Constants::MASTER_NODE_NAME.to_s
      ]
      command = Vagrant.new_command('ssh', args)
      command.execute!
      path = command.stdout
      KubernetesHarness.logger.warn('No kubeconfig created!') if path.empty?
      path
    end

    def self.cluster_ssh_key
      File.join KubernetesHarness::Clusters::Metadata.default_dir, '/ssh_key'
    end

    def self.playbook_path
      File.join Metadata.default_dir, 'site.yml'
    end

    def self.inventory_path
      File.join Metadata.default_dir, 'inventory'
    end

    def self.vagrant_up_disposable_cluster_or_exit!
      KubernetesHarness.logger.debug('🚀 Creating node new disposable cluster 🚀')
      vagrant_threads = []
      Constants::ALL_NODES.each do |node|
        KubernetesHarness.logger.debug("Starting thread for node #{node}")
        vagrant_threads << Thread.new do
          vagrant_command = Vagrant.new_command('up', [node])
          vagrant_command.execute!
          vagrant_command
        end
      end
      results = vagrant_threads.each(&:join).map(&:value)
      failures = results.filter { |result| !result.success? }
      raise failed_cluster_error(vagrant_command) unless failures.empty?
    end

    def self.failed_cluster_error(command)
      raise "Failed to start Kubernetes cluster. Here's why:\n\n#{command.stderr}"
    end
  end
end
