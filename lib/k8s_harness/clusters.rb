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
      create_ssh_key!
      vagrant_up_disposable_cluster_or_exit!
      cluster = ClusterInfo.new(master_ip_address_command: master_ip_address_command,
                                worker_ip_addresses_command: worker_ip_addresses_command,
                                docker_registry_command: docker_registry_command,
                                kubeconfig_path: 'not_yet',
                                ssh_key_path: cluster_ssh_key)
      Metadata.write!('cluster.yaml', cluster.to_yaml)
      cluster
    end

    def self.create_ssh_key!
      ssh_key_fp = File.join(Metadata.default_dir, 'ssh_key')
      return if File.exist? ssh_key_fp

      KubernetesHarness.nice_logger.info 'Creating a new SSH key for the cluster.'
      ssh_key_command = ShellCommand.new(
        "ssh-keygen -t rsa -f '#{ssh_key_fp}' -q -N ''"
      )
      raise 'Unable to create a SSH key for the cluster' unless ssh_key_command.execute!
    end

    def self.provision!(cluster_info)
      all_results = provision_nodes_in_parallel!(cluster_info)
      failures = all_results.filter { |thread| !thread.success? }
      raise failed_cluster_error(failures) unless failures.empty?

      cluster_info.kubeconfig_path = cluster_kubeconfig
      true
    end

    # TODO: tests missing
    def self.teardown!
      destroy_nodes_in_parallel!

      true
    end

    # TODO: tests missing
    def self.destroy_existing!
      destroy_nodes_in_parallel!
    end

    def self.destroy_nodes_in_parallel!
      if cluster_running?
        KubernetesHarness.logger.debug('🚨 Deleting all nodes! 🚨')
        vagrant_threads = []
        Constants::ALL_NODES.each do |node|
          KubernetesHarness.logger.debug("Starting thread for node #{node}")
          vagrant_threads << Thread.new do
            vagrant_command = Vagrant.new_command('destroy', ['-f', node])
            vagrant_command.execute!
            vagrant_command
          end
        end
        results = vagrant_threads.each(&:join).map(&:value)
        failures = results.filter { |result| !result.success? }
        raise failed_cluster_destroy_error(failures) unless failures.empty?

        delete_cluster_yaml_and_ssh_key!
      else
        KubernetesHarness.nice_logger.info('No clusters found to destroy. Stopping.')
      end
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
        '"sudo cat /etc/rancher/k3s/k3s.yaml"',
        Constants::MASTER_NODE_NAME.to_s
      ]
      command = Vagrant.new_command('ssh', args)
      command.execute!
      if command.stdout.empty?
        KubernetesHarness.logger.warn('No kubeconfig created!')
        return
      end
      Metadata.write!('kubeconfig', command.stdout)
      File.join Metadata.default_dir, 'kubeconfig'
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
      raise failed_cluster_error(failures) unless failures.empty?
    end

    def self.generate_err_msg(cmd)
      header = "From command '#{cmd.command}':"
      separator = '-' * (header.length + 4)

      <<~MESSAGE
        #{header}
        #{separator}

        #{cmd.stderr}
      MESSAGE
    end

    def self.failed_cluster_error(command)
      stderr = if command.is_a? Array
                 command.map do |cmd|
                   generate_err_msg(cmd.stderr)
                 end.flatten.join("\n\n")
               else
                 generate_err_msg(command.stderr)
               end
      raise "Failed to start Kubernetes cluster. Here's why:\n\n#{stderr}"
    end

    def self.failed_cluster_destroy_error(command)
      stderr = if command.is_a? Array
                 command.map(&:stderr).uniq!.join("\n")
               else
                 command.stderr
               end
      raise "Failed to delete Kubernetes cluster. Here's why:\n\n#{stderr}"
    end

    def self.delete_cluster_yaml_and_ssh_key!
      ['ssh_key', 'ssh_key.pub', 'cluster.yaml'].each do |file|
        Metadata.delete!(file)
      end
    end

    def self.cluster_running?
      vagrant_status_command = Vagrant.new_command('global-status')
      vagrant_status_command.execute!
      vagrant_status_command.stdout.match?(/k3s-/)
    end
  end
end
