# frozen_string_literal: true

require 'spec_helper'

describe 'Given an object that runs shell commands' do
  context 'When it is given a shell command' do
    before(:each) do
      @test_command = 'my awesome command'
      @test_stdout = 'foo'
      @test_rc = 42
    end
    context 'And no environment variables are provided' do
      example 'Then it executes it' do
        allow_any_instance_of(KubernetesHarness::ShellCommand)
          .to receive(:read_output_in_chunks)
          .and_return([@test_stdout, '', @test_rc])
        test_command = KubernetesHarness::ShellCommand.new(@test_command)
        test_command.execute!
        expect(test_command.stdout).to eq @test_stdout
        expect(test_command.success?(exit_code: @test_rc)).to be true
      end
    end

    context 'And environment variables are provided' do
      example 'Then it executes it' do
        mocked_env = { 'FOO' => 'bar' }
        allow_any_instance_of(KubernetesHarness::ShellCommand)
          .to receive(:read_output_in_chunks)
          .with(mocked_env)
          .and_return([@test_stdout, '', @test_rc])
        test_command = KubernetesHarness::ShellCommand.new(@test_command, environment: mocked_env)
        test_command.execute!
        expect(test_command.stdout).to eq @test_stdout
        expect(test_command.success?(exit_code: @test_rc)).to be true
      end
    end
  end
end
