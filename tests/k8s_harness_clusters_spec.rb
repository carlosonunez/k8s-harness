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
  context 'When I create the disposable cluster' do
    before(:each) do
      ENV['PWD'] = '/foo'
      @mocked_env = {
        VAGRANT_CWD: KubernetesHarness::Clusters::Metadata.default_dir,
        ANSIBLE_HOST_KEY_CHECKING: 'no',
        ANSIBLE_SSH_ARGS: '-o IdentitiesOnly=true'
      }
    end

    example 'Then a cluster is created if all commands process succesfully' do
      base_ip_address_command = [
        'vagrant ssh',
        '-c',
        "\"ip addr show dev eth1 | grep \'\\<inet\\>\' | awk \'{print \\$2}\' | cut -f1 -d \'/\'\"",
        '%%node%%'
      ].join(' ')
      master_ip_address_command = base_ip_address_command.gsub('%%node%%', 'k3s-node-0')
      worker_ip_address_command = base_ip_address_command.gsub('%%node%%', 'k3s-node-1')
      docker_registry_command = base_ip_address_command.gsub('%%node%%', 'k3s-registry')
      master_double = double(KubernetesHarness::ShellCommand,
                             command: master_ip_address_command,
                             execute!: true,
                             stdout: '',
                             environment: @mocked_env)
      worker_double = double(KubernetesHarness::ShellCommand,
                             command: worker_ip_address_command,
                             execute!: true,
                             stdout: '',
                             environment: @mocked_env)
      registry_double = double(KubernetesHarness::ShellCommand,
                               command: docker_registry_command,
                               execute!: true,
                               stdout: '',
                               environment: @mocked_env)
      allow(KubernetesHarness::Clusters::RequiredSoftware)
        .to receive(:ensure_installed_or_exit!)
        .and_return(true)
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(master_ip_address_command, environment: @mocked_env)
        .and_return(master_double)
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(worker_ip_address_command, environment: @mocked_env)
        .and_return(worker_double)
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(docker_registry_command, environment: @mocked_env)
        .and_return(registry_double)
      allow(KubernetesHarness::Clusters)
        .to receive(:vagrant_up_disposable_cluster_or_exit!)
        .and_return true
      allow(KubernetesHarness::Clusters)
        .to receive(:cluster_kubeconfig)
        .and_return '/path/to/kubeconfig'
      allow(KubernetesHarness::Clusters)
        .to receive(:cluster_ssh_key)
        .and_return '/path/to/ssh/key'
      expect(KubernetesHarness::Clusters::ClusterInfo)
        .to receive(:new)
        .with(master_ip_address_command: master_double,
              worker_ip_addresses_command: [worker_double],
              docker_registry_command: registry_double,
              kubeconfig_path: '/path/to/kubeconfig',
              ssh_key_path: '/path/to/ssh/key')
      expect(KubernetesHarness::Clusters::Metadata)
        .to receive(:write!)
        .with('cluster.yaml', "---\n")
      FileUtils.mkdir_p('/foo')
      KubernetesHarness::Clusters.create!
    end

    example 'Then a cluster is provisioned once it is created' do
      ansible_playbook_base_command = %w[
        ansible-playbook
        -i /metadata_dir/inventory
        -e "ansible_ssh_user=\"vagrant\""
        -e "k3s_token=12345"
        -l <HOST>
        --private-key /metadata_dir/ssh_key
        /metadata_dir/site.yml
      ].join(' ')
      cluster_info_double = double(
        KubernetesHarness::Clusters::ClusterInfo,
        master_ip_address: '1.2.3.4',
        worker_ip_addresses: ['4.5.6.7'],
        docker_registry_address: '8.9.0.1',
        kubernetes_cluster_token: '12345',
        kubeconfig_path: '/metadata_dir/inventory',
        ssh_key_path: '/metadata_dir/ssh_key'
      )
      ansible_playbook_master_command = ansible_playbook_base_command.gsub('<HOST>', '1.2.3.4')
      ansible_playbook_worker_command = ansible_playbook_base_command.gsub('<HOST>', '4.5.6.7')
      ansible_playbook_registry_command = ansible_playbook_base_command.gsub('<HOST>', '8.9.0.1')
      mocked_ansible_env = @mocked_env.reject! { |key| key.match? 'VAGRANT' }
      master_command_double = double(KubernetesHarness::ShellCommand,
                                     command: ansible_playbook_master_command,
                                     execute!: true,
                                     stdout: '',
                                     exitcode: 0,
                                     environment: mocked_ansible_env)
      worker_command_double = double(KubernetesHarness::ShellCommand,
                                     command: ansible_playbook_worker_command,
                                     execute!: true,
                                     stdout: '',
                                     exitcode: 0,
                                     environment: mocked_ansible_env)
      registry_command_double = double(KubernetesHarness::ShellCommand,
                                       command: ansible_playbook_registry_command,
                                       execute!: true,
                                       stdout: '',
                                       exitcode: 0,
                                       environment: mocked_ansible_env)
      allow(KubernetesHarness::Clusters::Metadata)
        .to receive(:default_dir)
        .and_return('/metadata_dir')
      expect(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(ansible_playbook_master_command, environment: @mocked_env)
        .and_return(master_command_double)
      expect(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(ansible_playbook_worker_command, environment: @mocked_env)
        .and_return(worker_command_double)
      expect(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(ansible_playbook_registry_command, environment: @mocked_env)
        .and_return(registry_command_double)
      expect(KubernetesHarness::Clusters.provision!(cluster_info_double))
        .to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
