# frozen_string_literal: true

require 'yaml'
require 'k8s_harness/paths'

module KubernetesHarness
  module Clusters
    # Simple module for interacting with Vagrant.
    module Ansible
      # for ansible-playbook
      module Playbook
        def self.create_run_against_single_host(playbook_fp:,
                                                inventory_fp:,
                                                ssh_key_path:,
                                                ip_address:,
                                                extra_vars:)
          log_new_run(playbook_fp, inventory_fp, ssh_key_path, ip_address, extra_vars)
          command_env = {
            ANSIBLE_HOST_KEY_CHECKING: 'no',
            ANSIBLE_SSH_ARGS: '-o IdentitiesOnly=true',
            ANSIBLE_COMMAND_WARNINGS: 'False',
            ANSIBLE_PYTHON_INTERPRETER: '/usr/bin/python'
          }
          KubernetesHarness::ShellCommand.new(
            command(playbook_fp, inventory_fp, ssh_key_path, ip_address, extra_vars),
            environment: command_env
          )
        end

        def self.command(playbook_fp, inventory_fp, ssh_key_path, ip_address, extra_vars)
          [
            'ansible-playbook',
            "-i #{inventory_fp}",
            "-e \"ansible_ssh_user=\\\"#{ENV['ANSIBLE_SSH_USER'] || 'vagrant'}\\\"\"",
            extra_vars.map { |var| "-e \"#{var}\"" },
            "-l #{ip_address}",
            "--private-key #{ssh_key_path}",
            playbook_fp
          ].flatten.join(' ')
        end

        def self.log_new_run(playbook_fp, inventory_fp, ssh_key_path, ip_address = '', extra_vars)
          KubernetesHarness.logger.info(
            <<~MESSAGE.strip
              Creating a new single-host Ansible Playbook run! \
              playbook: #{playbook_fp}, \
              inventory: #{inventory_fp}, \
              ssh_key: #{ssh_key_path}, \
              ip_address: #{ip_address}, \
              extra_vars: #{extra_vars}
            MESSAGE
          )
        end
      end
    end
  end
end
