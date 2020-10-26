# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe 'Given a CLI that runs k8s-harness' do
  before(:all) do
    @helpdoc = <<~HELPDOC
      Usage: k8s-harness [subcommand] [options]
      Test your apps in disposable Kubernetes clusters

      Sub-commands:

      #{'run'.ljust(20)} Runs tests
      #{'validate'.ljust(20)} Validates .k8sharness files

      See k8s-harness [subcommand] --help for more specific options.

      Global options:
          #{'-d, --debug'.ljust(32)} Show debug output
          #{'-h, --help'.ljust(32)} Displays this help message
    HELPDOC
  end

  context 'When I run it with no options' do
    example 'Then it prints a usage doc' do
      example_args = []
      expect { KubernetesHarness::CLI.parse(example_args) }
        .to output(@helpdoc).to_stdout
    end
  end

  ['-h', '--help'].each do |help_option|
    context "When I run #{help_option}" do
      example 'Then it prints a usage doc' do
        example_args = [help_option]
        expect { KubernetesHarness::CLI.parse(example_args) }.to output(@helpdoc).to_stdout
      end
    end
  end

  context "When I run 'validate'" do
    example 'Then it runs the validate function' do
      allow(KubernetesHarness::CLI)
        .to receive(:call_entrypoint)
        .with('validate')
        .and_return("Hi, I'm TestFile!")
      example_args = ['validate']
      expect(KubernetesHarness::CLI.parse(example_args)).to eq "Hi, I'm TestFile!"
    end
  end
end
# rubocop:enable Metrics/BlockLength
