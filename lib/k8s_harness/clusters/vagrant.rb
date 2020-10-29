# frozen_string_literal: true

module KubernetesHarness
  module Clusters
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

      def self.create_and_execute_new_ssh_command(node_name, command)
        args = ['-c', command, node_name]
        command = Vagrant.new_command('ssh', args)
        command.execute!
        command
      end
    end
  end
end
