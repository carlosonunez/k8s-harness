# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
describe 'Given a function that creates new disposable clusters' do
  context 'When I run it' do
    before(:all) do
      @harness_spec = {
        setup: "sh -c 'echo \"Running setup\"'",
        test: "sh -c 'echo \"Running tests\"'",
        teardown: "sh -c 'echo \"Running teardown\"'"
      }
    end
    context "And I'm creating metadata" do
      example 'Then it creates a hidden directory for metadata' do
        ENV['PWD'] = '/foo'
        FakeFS do
          FakeFS::FileSystem.clone(KubernetesHarness::Paths.include_dir)
          KubernetesHarness::Clusters::Metadata.create_dir!
          expect(File).to exist '/foo/.k8sharness_data'
        end
      end

      example 'Then it copies the right stuff into that directory' do
        expected_files = %w[Vagrantfile inventory site.yml]
        allow(KubernetesHarness::Clusters::Metadata)
          .to receive(:create_dir!)
          .and_return true
        ENV['PWD'] = '/foo'
        FakeFS do
          FileUtils.mkdir_p '/foo/.k8sharness_data'
          KubernetesHarness::Clusters::Metadata.initialize!
          expected_files.each do |file|
            expected_file = "/foo/.k8sharness_data/#{file}"
            expect(File).to exist(expected_file),
                            "File expected to exist but does not: #{expected_file}"
          end
        end
      end
    end

    context "And I'm verifying that my machine is configured correctly" do
      example "Then it fails if I don't have necessary software" do
        mocked_software = [
          {
            name: 'foo',
            version_check: 'foo --version'
          },
          {
            name: 'bar',
            version_check: 'bar --version'
          },
          {
            name: 'baz',
            version_check: 'baz --version'
          }
        ]
        allow(KubernetesHarness::Clusters::RequiredSoftware)
          .to receive(:software)
          .and_return(mocked_software)
        mocked_software.each do |app|
          mocked_result = app[:name] == 'baz'
          command_string = "sh -c '#{app[:version_check]}; exit $?'"
          shellcommand_double = double(KubernetesHarness::ShellCommand,
                                       success?: mocked_result,
                                       execute!: nil)
          allow(KubernetesHarness::ShellCommand)
            .to receive(:new)
            .with(command_string)
            .and_return shellcommand_double
        end
        error_message = <<~MESSAGE.strip
          You are missing the following software:

          - foo
          - bar

          Please consult the README to learn what you'll need to install \
          before using k8s-harness.
        MESSAGE
        expect { KubernetesHarness::Clusters::RequiredSoftware.ensure_installed_or_exit! }
          .to raise_error(error_message)
      end
      example 'Then it passes if I have all of the necessary software' do
        mocked_software = [
          {
            name: 'foo',
            version_check: 'foo --version'
          },
          {
            name: 'bar',
            version_check: 'bar --version'
          }
        ]
        allow(KubernetesHarness::Clusters::RequiredSoftware)
          .to receive(:software)
          .and_return(mocked_software)
        mocked_software.each do |app|
          shellcommand_double = double(KubernetesHarness::ShellCommand,
                                       success?: true,
                                       execute!: nil)
          command_string = "sh -c '#{app[:version_check]}; exit $?'"
          allow(KubernetesHarness::ShellCommand)
            .to receive(:new)
            .with(command_string)
            .and_return shellcommand_double
        end
        expect { KubernetesHarness::Clusters::RequiredSoftware.ensure_installed_or_exit! }
          .not_to raise_error
      end
    end
  end

  context 'When I create SSH keys' do
    example 'Then it creates the keypair' do
      ssh_keygen_command = "ssh-keygen -t rsa -f '/foo/.k8sharness_data/ssh_key' -q -N ''"
      command_double = double(KubernetesHarness::ShellCommand,
                              command: ssh_keygen_command,
                              execute!: true,
                              exitcode: 0)
      expect(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(ssh_keygen_command)
        .and_return(command_double)
      KubernetesHarness::Clusters.create_ssh_key!
    end
  end
  context 'When I create the disposable cluster' do
    before(:each) do
      ENV['PWD'] = '/foo'
      @mocked_env = {
        VAGRANT_CWD: KubernetesHarness::Clusters::Metadata.default_dir,
        ANSIBLE_HOST_KEY_CHECKING: 'no',
        ANSIBLE_COMMAND_WARNINGS: 'False',
        ANSIBLE_SSH_ARGS: '-o IdentitiesOnly=true',
        ANSIBLE_PYTHON_INTERPRETER: '/usr/bin/python'
      }
    end

    example 'Then a cluster is created if all commands process succesfully' do
      base_ip_address_command = [
        'vagrant ssh',
        '-c',
        "\"ip addr show dev eth1 | grep \'\\<inet\\>\' | awk \'{print \\$2}\' | cut -f1 -d \'/\'\"",
        '%%node%%'
      ].join(' ')
      master_ip_address_command = { master: base_ip_address_command.gsub('%%node%%', 'k3s-node-0') }
      worker_ip_address_command = { worker: base_ip_address_command.gsub('%%node%%', 'k3s-node-1') }
      docker_registry_command = { registry: base_ip_address_command.gsub('%%node%%', 'k3s-registry') }
      all_command_mocks = {}
      [master_ip_address_command,
       worker_ip_address_command,
       docker_registry_command].each do |kvp|
        double_name = kvp.keys.first
        command = kvp[double_name]
        vagrant_env = @mocked_env.select { |k| k.to_s.match?(/VAGRANT/) }
        shell_command_mock = double(KubernetesHarness::ShellCommand,
                                    command: command,
                                    execute!: true,
                                    stdout: '',
                                    exitcode: 0,
                                    environment: vagrant_env)
        allow(KubernetesHarness::ShellCommand)
          .to receive(:new)
          .with(command, environment: vagrant_env)
          .and_return(shell_command_mock)
        all_command_mocks[double_name] = shell_command_mock
      end
      allow(KubernetesHarness::Clusters)
        .to receive(:create_ssh_key!)
        .and_return true
      allow(KubernetesHarness::Clusters::RequiredSoftware)
        .to receive(:ensure_installed_or_exit!)
        .and_return(true)
      allow(KubernetesHarness::Clusters)
        .to receive(:vagrant_up_disposable_cluster_or_exit!)
        .and_return true
      allow(KubernetesHarness::Clusters)
        .to receive(:cluster_ssh_key)
        .and_return '/path/to/ssh/key'
      expect(KubernetesHarness::Clusters::ClusterInfo)
        .to receive(:new)
        .with(master_ip_address_command: all_command_mocks[:master],
              worker_ip_addresses_command: [all_command_mocks[:worker]],
              docker_registry_command: all_command_mocks[:registry],
              kubeconfig_path: 'not_yet',
              ssh_key_path: '/path/to/ssh/key')
      expect(KubernetesHarness::Clusters::Metadata)
        .to receive(:write!)
        .with('cluster.yaml', /^--- {0,}\n/)
      FileUtils.mkdir_p('/foo')
      KubernetesHarness::Clusters.create!
    end
  end

  context 'When I provision the cluster' do
    before(:each) do
      ENV['PWD'] = '/foo'
      @mocked_env = {
        VAGRANT_CWD: KubernetesHarness::Clusters::Metadata.default_dir,
        ANSIBLE_HOST_KEY_CHECKING: 'no',
        ANSIBLE_COMMAND_WARNINGS: 'False',
        ANSIBLE_SSH_ARGS: '-o IdentitiesOnly=true',
        ANSIBLE_PYTHON_INTERPRETER: '/usr/bin/python'
      }
    end
    example 'Then a cluster is provisioned once it is created' do
      # No, rubocop, the quotes are needed here.
      # rubocop: disable Lint/PercentStringArray
      ansible_playbook_base_command = %w[
        ansible-playbook
        -i /metadata_dir/inventory
        -e "ansible_ssh_user=\"vagrant\""
        -e "k3s_token=12345"
        -l <HOST>
        --private-key /metadata_dir/ssh_key
        /metadata_dir/site.yml
      ].join(' ')
      # rubocop: enable Lint/PercentStringArray
      cluster_info_double = double(
        KubernetesHarness::Clusters::ClusterInfo,
        master_ip_address: '1.2.3.4',
        worker_ip_addresses: ['4.5.6.7'],
        docker_registry_address: '8.9.0.1',
        kubernetes_cluster_token: '12345',
        ssh_key_path: '/metadata_dir/ssh_key'
      )
      ansible_playbook_master_command = ansible_playbook_base_command.gsub('<HOST>', '1.2.3.4')
      ansible_playbook_worker_command = ansible_playbook_base_command.gsub('<HOST>', '4.5.6.7')
      ansible_playbook_registry_command = ansible_playbook_base_command.gsub('<HOST>', '8.9.0.1')
      [
        ansible_playbook_worker_command,
        ansible_playbook_registry_command,
        ansible_playbook_master_command
      ].each do |command|
        shell_command_mock = double(KubernetesHarness::ShellCommand,
                                    command: command,
                                    execute!: true,
                                    stdout: '',
                                    exitcode: 0,
                                    success?: true)
        ansible_env = @mocked_env.select { |key| key.match? 'ANSIBLE' }
        allow(KubernetesHarness::ShellCommand)
          .to receive(:new)
          .with(command, environment: ansible_env)
          .and_return(shell_command_mock)
      end
      allow(KubernetesHarness::Clusters)
        .to receive(:cluster_kubeconfig)
        .and_return '/path/to/kubeconfig'
      allow(KubernetesHarness::Clusters)
        .to receive(:create_ssh_key!)
        .and_return true
      allow(KubernetesHarness::Clusters::Metadata)
        .to receive(:default_dir)
        .and_return('/metadata_dir')
      expect(cluster_info_double)
        .to receive(:kubeconfig_path=)
        .with '/path/to/kubeconfig'
      expect(KubernetesHarness::Clusters.provision!(cluster_info_double))
        .to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
