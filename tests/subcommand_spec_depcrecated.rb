# frozen_string_literal: true

require 'spec_helper'
require 'k8s_harness/subcommand'

# rubocop: disable Metrics/BlockLength
describe 'Given a module that contains subcommands' do
  context 'When I execute run' do
    context 'And I ask for usage' do
      example 'It should exit because the CLI handles displaying usage' do
        expect(KubernetesHarness::Subcommand.run({ show_usage: true })).to be true
      end
    end

    context 'And I run it by itself' do
      before(:each) do
        ENV['PWD'] = '/foo'
        cluster_info = {
          master_ip_address: 'foo',
          worker_ip_addresses: ['bar'],
          docker_registry_address: 'baz',
          kubeconfig_path: '/foo',
          ssh_key_path: '/bar'
        }
        @cluster_info_double = double(
          KubernetesHarness::Clusters::ClusterInfo,
          cluster_info
        )
        @logger_double = double(Logger,
                                info: nil,
                                debug: nil)
        @expected_yaml_file = YAML.dump(cluster_info)
        # This is an anti-pattern since it is chaining tests together.
        # This means that any method that involves creating clusters will have to
        # update this hash in order for tests to pass.
        # TODO: Fix this.
        @all_stdout_expected = {
          create: ['Creating your cluster now. It will be ready in a few minutes.',
                   'Cluster has been created. Details are below and in YAML at /foo/.k8sharness_data/cluster.yaml:',
                   "  Master address: 'foo'",
                   '  Worker addresses: ["bar"]',
                   '  Kubeconfig path: /foo',
                   '  SSH key path: /bar'],
          provision: [
            'Provisioning your cluster. Hang tight; almost there!'
          ]
        }
      end
      example 'It should create a cluster' do
        FakeFS do
          allow(Logger).to receive(:new).and_return(@logger_double)
          allow(KubernetesHarness::Clusters)
            .to receive(:provision!)
            .and_return(true)
          expect(KubernetesHarness::Clusters)
            .to receive(:create!)
            .at_least(1).times
            .and_return(@cluster_info_double)
          @all_stdout_expected[:create].each do |message|
            expect(@logger_double)
              .to receive(:info)
              .with(message)
          end
          KubernetesHarness::Subcommand.run
        end
      end
      example 'It should provision the cluster' do
        FakeFS do
          allow(Logger).to receive(:new).and_return(@logger_double)
          allow(KubernetesHarness::Clusters)
            .to receive(:provision_nodes_in_parallel!)
            .and_return([command_double])
          allow(KubernetesHarness::Clusters)
            .to receive(:create!)
            .and_return(@cluster_info_double)
          expect(KubernetesHarness::Clusters)
            .to receive(:provision!)
            .with(@cluster_info_double)
            .and_return(true)
          (@all_stdout_expected[:create] + @all_stdout_expected[:provision]).each do |message|
            expect(@logger_double)
              .to receive(:info)
              .with(message)
          end
          KubernetesHarness::Subcommand.run
        end
      end
    end
  end
  context 'When I execute validate' do
    context 'And I ask for usage' do
      example 'It should exit because the CLI handles displaying usage' do
        expect(KubernetesHarness::Subcommand.validate({ show_usage: true })).to be true
      end
    end

    context 'And I run it by itself' do
      example 'It should validate a Harness file' do
        expect(KubernetesHarness::HarnessFile).to receive(:validate)
        KubernetesHarness::Subcommand.validate
      end
    end
  end
end
# rubocop: enable Metrics/BlockLength
