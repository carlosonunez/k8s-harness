# frozen_string_literal: true

require 'spec_helper'

describe 'Given an object that runs shell commands' do
  context 'When it is given a shell command' do
    before(:each) do
      @test_command = 'my awesome command'
      @test_stdout = 'foo'
      @test_rc = 42
      @process_double = double(Process, exitstatus: @test_rc)
    end
    context 'And no environment variables are provided' do
      example 'Then it executes it' do
        allow(Open3)
          .to receive(:capture3)
          .with(@test_command)
          .and_return([@test_stdout, '', @process_double])
        test_command = KubernetesHarness::ShellCommand.new(@test_command)
        test_command.execute!
        expect(test_command.stdout).to eq @test_stdout
        expect(test_command.success?(exit_code: @test_rc)).to be true
      end
    end

    context 'And environment variables are provided' do
      example 'Then it executes it' do
        mocked_env = { 'FOO' => 'bar' }
        allow(Open3)
          .to receive(:capture3)
          .with(mocked_env, @test_command)
          .and_return([@test_stdout, '', @process_double])
        test_command = KubernetesHarness::ShellCommand.new(@test_command, environment: mocked_env)
        test_command.execute!
        expect(test_command.stdout).to eq @test_stdout
        expect(test_command.success?(exit_code: @test_rc)).to be true
      end
    end
  end
end
