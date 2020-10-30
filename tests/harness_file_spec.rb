# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe 'Given a function that renders .k8sharness files' do
  context 'When it tries to find where .k8sharness is' do
    context 'And I provide it with no options' do
      example 'Then it tries to render the .k8sharness file at the root of your pwd' do
        FakeFS do
          FileUtils.mkdir_p '/foo'
          File.write('/foo/.k8sharness', '{}')
          allow(Dir).to receive(:pwd).and_return '/foo'
          allow(KubernetesHarness::HarnessFile).to receive(:test_present?).and_return true
          expect(KubernetesHarness::HarnessFile.render({})).to eq({})
        end
      end
    end

    context 'And I provide it with an alternate Harness file' do
      example 'Then it tries to render the .k8sharness file at the path provided' do
        FakeFS do
          test_options = { alternate_harnessfile: '/bar/.k8sharness' }
          FileUtils.mkdir_p '/bar'
          File.write('/bar/.k8sharness', '{}')
          allow(KubernetesHarness::HarnessFile).to receive(:test_present?).and_return true
          expect(KubernetesHarness::HarnessFile.render(test_options)).to eq({})
        end
      end
    end
  end

  context 'When it renders them' do
    test_cases = {
      invalid_missing_test_key: {
        name: 'missing "test" key',
        file: '.k8sharness.missing_tests_key',
        failure: true,
        error: <<~MESSAGE.strip
          It appears that your test isn't defined in [HARNESS_FILE]. Ensure that \
          a key called 'test' is in [HARNESS_FILE]. See .k8sharness.example for \
          an example of what a valid .k8sharness looks like.
        MESSAGE
      },
      valid_missing_setup_key: {
        name: 'missing "setup" key',
        file: '.k8sharness.missing_setup_key',
        failure: false,
        expected: { test: "sh -c 'foo'", teardown: "sh -c 'bar'" }
      },
      valid_missing_teardown_key: {
        name: 'missing "teardown" key',
        file: '.k8sharness.missing_teardown_key',
        failure: false,
        expected: { test: "sh -c 'foo'", setup: "sh -c 'bar'" }
      },
      key_already_has_sh_command: {
        name: 'file is valid but one of the keys already has a "sh" command in it',
        file: '.k8sharness.key_already_has_sh_command',
        failure: false,
        expected: { test: "sh -c 'bar'", setup: 'sh -c "Foo"' }
      },
      key_references_a_script: {
        name: 'file is valid but one of the keys references a script',
        file: '.k8sharness.key_references_script',
        failure: false,
        expected: { test: "sh -c 'bar'", setup: 'sh foo.sh' }
      }
    }
    test_cases.each_key do |test_case|
      expected_result = test_cases[test_case][:failure] ? 'fail' : 'succeed'
      condition = test_cases[test_case][:name]
      expected_object = test_cases[test_case][:expected] || {}
      expected_error = if test_cases[test_case].key? :error
                         test_cases[test_case][:error].gsub(/\[HARNESS_FILE\]/, '/foo/.k8sharness')
                       else
                         String.new
                       end
      test_file = "#{ENV['PWD']}/tests/fixtures/#{test_cases[test_case][:file]}"
      example "Then render should #{expected_result} because '#{condition}'" do
        FakeFS do
          FakeFS::FileSystem.clone(test_file)
          FileUtils.mkdir_p('/foo')
          FileUtils.copy(test_file, '/foo/.k8sharness')
          allow(Dir).to receive(:pwd).and_return('/foo')
          if test_cases[test_case][:failure]
            expect { KubernetesHarness::HarnessFile.render }
              .to raise_error(KeyError, expected_error)
          else
            expect(KubernetesHarness::HarnessFile.render)
              .to eq(expected_object)
          end
        end
      end
    end
  end
end

describe 'Given a function that validates .k8sharness files' do
  context 'When I run it' do
    example 'Then I am given a YAML representation of my rendered file', :wip do
      test_file = "#{ENV['PWD']}/tests/fixtures/.k8sharness.valid_with_all_keys"
      expected_output = {
        setup: 'sh setup.sh',
        test: "sh -c 'echo Look! A test!'",
        teardown: 'sh teardown.sh'
      }
      FakeFS do
        FakeFS::FileSystem.clone(test_file)
        FileUtils.mkdir_p '/foo'
        FileUtils.cp(test_file, '/foo/.k8sharness')
        allow(Dir).to receive(:pwd).and_return('/foo')
        expect(KubernetesHarness::HarnessFile.validate)
          .to eq expected_output
      end
    end
  end
end

describe 'Given a function that sets up a test suite' do
  context 'When the Harness file does not have a setup instruction' do
    example 'Then it does not run' do
      harness_file_double = {
        test: 'foo'
      }
      allow(KubernetesHarness::HarnessFile)
        .to receive(:render)
        .and_return(harness_file_double)
      expect(KubernetesHarness::HarnessFile.execute_setup!({}))
        .to be nil
    end
  end
  context 'When the Harness file does have a setup instruction' do
    example 'Then it runs' do
      command_double = double(KubernetesHarness::ShellCommand,
                              command: 'sh -c "bar"',
                              execute!: true,
                              stderr: '',
                              stdout: 'Bar.')
      harness_file_mock = {
        setup: 'sh -c "bar"',
        test: 'sh -c "foo"'
      }
      allow(KubernetesHarness::HarnessFile)
        .to receive(:render)
        .and_return(harness_file_mock)
      allow(KubernetesHarness::ShellCommand)
        .to receive(:new)
        .with('sh -c "bar"')
        .and_return(command_double)
      expect { KubernetesHarness::HarnessFile.execute_setup!({}) }
        .to output("Bar.\n")
        .to_stdout
    end
  end
end
# rubocop:enable Metrics/BlockLength
