# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
describe 'Given a class that provides information about a cluster from Vagrant info' do
  context 'When I create a new instance of it' do
    before(:each) do
      allow(Digest::MD5).to receive(:hexdigest).and_return '12345'
      @master_ip_address_double = double(KubernetesHarness::ShellCommand,
                                         command: 'anything',
                                         exitcode: 87,
                                         execute!: true,
                                         stdout: '1.2.3.4')
      @docker_registry_command_double = double(KubernetesHarness::ShellCommand,
                                               command: 'anything',
                                               exitcode: 87,
                                               execute!: true,
                                               stdout: '8.9.0.1')
      @worker_ip_addresses_double = double(KubernetesHarness::ShellCommand,
                                           command: 'anything',
                                           exitcode: 14,
                                           execute!: true,
                                           stdout: "1.2.3.5\n1.2.3.6\n1.2.3.7")
      @cluster_info = KubernetesHarness::Clusters::ClusterInfo.new(
        master_ip_address_command: @master_ip_address_double,
        worker_ip_addresses_command: [@worker_ip_addresses_double],
        docker_registry_command: @docker_registry_command_double,
        kubeconfig_path: '/path/to/kubeconfig',
        ssh_key_path: '/path/to/ssh_key'
      )
    end
    example 'Then it should have the correct master IP address' do
      expect(@cluster_info.master_ip_address).to eq '1.2.3.4'
    end

    example 'Then it should have the correct worker IP address' do
      expect(@cluster_info.worker_ip_addresses).to eq ['1.2.3.5',
                                                       '1.2.3.6',
                                                       '1.2.3.7']
    end

    example 'Then it should have the correct Docker registry address' do
      expect(@cluster_info.docker_registry_address).to eq '8.9.0.1'
    end

    example 'Then it should have the correct cluser token' do
      expect(@cluster_info.kubernetes_cluster_token).to eq '12345'
    end

    example 'Then it should have the correct kubeconfig and SSH key paths' do
      expect(@cluster_info.kubeconfig_path).to eq '/path/to/kubeconfig'
      expect(@cluster_info.ssh_key_path).to eq '/path/to/ssh_key'
    end
  end
end
# rubocop:enable Metrics/BlockLength
