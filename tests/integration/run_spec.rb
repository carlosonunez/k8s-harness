# frozen_string_literal: true

require 'open3'
require 'spec_helper'

describe 'Given the k8s-harness app' do
  context 'When I execute "run"' do
    before(:each) do
      FakeFS.deactivate!
      ENV['PWD'] = "#{ENV['PWD']}/tests/integration"
    end

    after(:each) do |example|
      KubernetesHarness::CLI.parse(['destroy']) if example.exception
      FakeFS.activate!
    end

    # We need $STDOUT and $STDERR for seeing whether our test ran.
    example 'Then a test should have executed', :integration do
      expect { KubernetesHarness::CLI.parse(['run']) }
        .to output(/Your test ran successfully!/)
        .to_stdout
    end
  end
end
