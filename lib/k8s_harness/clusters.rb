# frozen_string_literal: true

require 'k8s_harness/shell_command'
require 'k8s_harness/clusters/cluster_info'
require 'k8s_harness/clusters/metadata'
require 'k8s_harness/clusters/required_software'

module KubernetesHarness
  # Handles bring up and deletion of disposable clusters.
  module Clusters
    module Constants
      MASTER_NODE_NAME = 'k3s-node-0'
      WORKER_NODE_NAMES = ['k3s-node-1'].freeze
    end

    # Simple module for interacting with Vagrant.
    module Vagrant
      def self.new_command(command, args = nil)
        command_env = {
          VAGRANT_CWD: Metadata.default_dir,
          ANSIBLE_HOST_KEY_CHECKING: 'no',
          ANSIBLE_SSH_ARGS: '-o IdentitiesOnly=true'
        }
        command = "vagrant #{command}"
        command = "#{command} #{[args].flatten.join(' ')}" unless args.nil?
        KubernetesHarness::ShellCommand.new(command, environment: command_env)
      end
    end

    def self.create!
      vagrant_up_disposable_cluster_or_exit!
      ClusterInfo.new(master_ip_address_command: master_ip_address_command,
                      worker_ip_addresses_command: worker_ip_addresses_command,
                      kubeconfig_path: cluster_kubeconfig,
                      ssh_key_path: cluster_ssh_key)
    end

    def self.worker_ip_addresses_command
      commands = []
      Constants::WORKER_NODE_NAMES.each do |node|
        args = ['-c',
                "\"ip addr show dev eth0 | grep \'\\<inet\\>\' | awk \'{print $2}\' | cut -f1 -d \'/\'\"",
                node]
        command = Vagrant.new_command('ssh', args)
        command.execute!
        commands.push command
      end
      commands
    end

    def self.master_ip_address_command
      args = [
        '-c',
        "\"ip addr show dev eth0 | grep \'\\<inet\\>\' | awk \'{print $2}\' | cut -f1 -d \'/\'\"",
        Constants::MASTER_NODE_NAME.to_s
      ]
      command = Vagrant.new_command('ssh', args)
      command.execute!
      command
    end

    def self.cluster_kubeconfig
      args = [
        '-c',
        '"cat /etc/rancher/k3s/k3s.yaml"',
        Constants::MASTER_NODE_NAME.to_s
      ]
      command = Vagrant.new_command('ssh', args)
      command.execute!
      command
    end

    def self.cluster_ssh_key
      File.join KubernetesHarness::Clusters::Metadata.default_dir, '/ssh_key'
    end

    def self.vagrant_up_disposable_cluster_or_exit!
      KubernetesHarness.logger.debug('🚀 Creating new disposable cluster 🚀')
      vagrant_command = Vagrant.new_command('up')
      vagrant_command.execute!
      raise 'Failed to start Kubernetes cluster' unless vagrant_command.success?
    end

    private_class_method :vagrant_up_disposable_cluster_or_exit!, :master_ip_address_command
  end
end
