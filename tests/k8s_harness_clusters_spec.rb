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
        allow(Dir).to receive(:pwd).and_return('/foo')
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
        allow(Dir).to receive(:pwd).and_return('/foo')
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
        mocked_software = {
          foo: {
            program_name: 'foo',
            version_check: 'foo --version'
          },
          bar: {
            program_name: 'bar',
            version_check: 'bar --version'
          },
          baz: {
            program_name: 'baz',
            version_check: 'baz --version'
          }
        }
        allow(KubernetesHarness::Clusters::RequiredSoftware)
          .to receive(:software)
          .and_return(mocked_software)
        mocked_software.each_key do |app|
          mocked_result = mocked_software[app][:program_name] == 'baz'
          shellcommand_double = double(KubernetesHarness::ShellCommand,
                                       success?: mocked_result,
                                       execute!: nil)
          allow(KubernetesHarness::ShellCommand)
            .to receive(:new)
            .with(mocked_software[app][:version_check])
            .and_return shellcommand_double
        end
        error_message = <<~MESSAGE.strip
          You are missing the following software:

          - foo
          - bar

          Please consult the README to learn what you'll need to install \
          before using k8s-harness.
        MESSAGE
        expect { KubernetesHarness::Clusters::RequiredSoftware.installed? }
          .to raise_error(error_message)
      end
      example 'Then it passes if I have all of the necessary software' do
        mocked_software = {
          foo: {
            program_name: 'foo',
            version_check: 'foo --version'
          },
          bar: {
            program_name: 'bar',
            version_check: 'bar --version'
          }
        }
        allow(KubernetesHarness::Clusters::RequiredSoftware)
          .to receive(:software)
          .and_return(mocked_software)
        mocked_software.each_key do |app|
          shellcommand_double = double(KubernetesHarness::ShellCommand,
                                       success?: true,
                                       execute!: nil)
          allow(KubernetesHarness::ShellCommand)
            .to receive(:new)
            .with(mocked_software[app][:version_check])
            .and_return shellcommand_double
        end
        expect { KubernetesHarness::Clusters::RequiredSoftware.installed? }
          .not_to raise_error
      end
    end
  end
  context 'When I create the disposable cluster' do
    before(:each) do
      allow(Dir).to receive(:pwd).and_return('/foo')
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
        "\"ip addr show dev eth0 | grep \'\\<inet\\>\' | awk \'{print $2}\' | cut -f1 -d \'/\'\"",
        '%%node%%'
      ].join(' ')
      master_ip_address_command = base_ip_address_command.gsub('%%node%%', 'k3s-node-0')
      worker_ip_address_command = base_ip_address_command.gsub('%%node%%', 'k3s-node-1')
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
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(master_ip_address_command, environment: @mocked_env)
        .and_return(master_double)
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with(worker_ip_address_command, environment: @mocked_env)
        .and_return(worker_double)
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
              kubeconfig_path: '/path/to/kubeconfig',
              ssh_key_path: '/path/to/ssh/key')
      KubernetesHarness::Clusters.create!
    end
  end
end
# rubocop:enable Metrics/BlockLength
