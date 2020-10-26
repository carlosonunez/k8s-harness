# frozen_string_literal: true

require 'optparse'
require 'k8s_harness/harness_file'

# KubernetesHarness
module KubernetesHarness
  # This module contains everything CLI-related.
  # We're using it as the entry-point for k8s-harness.
  module CLI
    @options = {
      base: {}
    }
    @subcommands = {
      run: {
        description: 'Runs tests',
        option_parser: OptionParser.new do |opts|
          opts.banner = 'Usage: k8s-harness run [options]'
          opts.separator 'Runs tests'
          opts.separator ''
          opts.separator 'Commands:'
          opts.on_tail('-h', '--help', 'Displays this help message') do
            puts opts
          end
        end
      },
      validate: {
        description: 'Validates .k8sharness files',
        entrypoint: KubernetesHarness::HarnessFile.method(:validate),
        option_parser: OptionParser.new do |opts|
          opts.banner = 'Usage: k8s-harness validate [options]'
          opts.separator 'Validates that a .k8sharness file is correct'
          opts.separator ''
          opts.separator 'Commands:'
          opts.on_tail('-h', '--help', 'Displays this help message') do
            puts opts
          end
        end
      }
    }

    @base_command = OptionParser.new do |opts|
      opts.banner = 'Usage: k8s-harness [subcommand] [options]'
      opts.separator 'Test your apps in disposable Kubernetes clusters'
      opts.separator ''
      opts.separator 'Sub-commands:'
      opts.separator ''
      @subcommands.each_key do |subcommand|
        opts.separator "#{subcommand.to_s.ljust(20)} #{@subcommands[subcommand][:description]}"
      end
      opts.separator ''
      opts.separator 'See k8s-harness [subcommand] --help for more specific options.'
      opts.separator ''
      opts.separator 'Global options:'
      opts.on('-d', '--debug', 'Show debug output') do
        add_option(options: { enable_debug_logging: true })
      end
      opts.on_tail('-h', '--help', 'Displays this help message') do
        add_option(options: { help: opts.help })
      end
    end

    def self.add_option(options:, subcommand: nil)
      if subcommand.nil?
        @options[:base].merge!(options)
      else
        @options[subcommand].merge!(options)
      end
    end

    def self.parse(args)
      args.push('-h') if args.empty?
      @base_command.order!(args)
      subcommand = args.shift
      if subcommand.nil?
        puts @options[:base][:help]
      else
        @subcommands[subcommand.to_sym][:option_parser].order!(args)
        call_entrypoint(subcommand)
      end
    end

    def self.call_entrypoint(subcommand)
      @subcommands[subcommand.to_sym][:entrypoint].call(@options)
    end
  end
end
