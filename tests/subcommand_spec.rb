# frozen_string_literal: true

require 'spec_helper'
require 'k8s_harness/subcommand'

describe 'Given a module that contains subcommands' do
  context 'When I execute run' do
    context 'And I ask for usage' do
      example 'It should exit because the CLI handles displaying usage' do
        expect(KubernetesHarness::Subcommand.run({ show_usage: true })).to be true
      end
    end

    context 'And I run it by itself' do
      example 'It should create a cluster' do
        FakeFS.deactivate!
        cluster_info_double = double(
          KubernetesHarness::Clusters::ClusterInfo,
          master_ip_address: 'foo',
          worker_ip_addresses: ['bar'],
          kubeconfig_path: '/foo',
          ssh_key_path: '/bar'
        )
        expect(KubernetesHarness::Clusters).to receive(:create!).and_return(cluster_info_double)
        expect { KubernetesHarness::Subcommand.run }
          .to output('--> Creating your cluster now. This might take a few minutes.')
          .to_stdout_from_any_process
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
