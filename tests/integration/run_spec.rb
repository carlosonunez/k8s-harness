# frozen_string_literal: true

require 'open3'
require 'spec_helper'

describe 'Given the k8s-harness app' do
  context 'When I execute "run"' do
    before(:each) do
      FakeFS.deactivate!
      ENV['PWD'] = "#{ENV['PWD']}/tests/integration"
      argv = ['run']
      KubernetesHarness::CLI.parse(argv)
    end

    example 'Then a test should have executed', :integration do
      expect($STDERR).to eq ''
      expect($STDOUT).to match(/Your test ran successfully!/)
    end
  end
end
