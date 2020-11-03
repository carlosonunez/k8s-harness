# frozen_string_literal: true

require 'optparse'
require 'k8s_harness/subcommand'

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
          opts.on('-h', '--help', 'Displays this help message') do
            add_option(options: { show_usage: true }, subcommand: :run)
            puts opts
          end
          opts.on('--disable-teardown', 'Keeps the cluster up for local testing') do
            add_option(options: { disable_teardown: true }, subcommand: :run)
          end
        end
      },
      validate: {
        description: 'Validates .k8sharness files',
        option_parser: OptionParser.new do |opts|
          opts.banner = 'Usage: k8s-harness validate [options]'
          opts.separator 'Validates that a .k8sharness file is correct'
          opts.separator ''
          opts.separator 'Commands:'
          opts.on('-h', '--help', 'Displays this help message') do
            add_option(options: { show_usage: true }, subcommand: :validate)
            puts opts
          end
        end
      },
      destroy: {
        description: 'Deletes a live cluster provisioned by k8s-harness WITHOUT WARNING.',
        option_parser: OptionParser.new do |opts|
          opts.banner = 'Usage: k8s-harness destroy [options]'
          opts.separator 'Deletes live clusters provisioned by k8s-harness WITHOUT WARNING'
          opts.separator ''
          opts.separator 'Commands:'
          opts.on('-h', '--help', 'Displays this help message') do
            add_option(options: { show_usage: true }, subcommand: :destroy)
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
        opts.separator "    #{subcommand.to_s.ljust(20)} #{@subcommands[subcommand][:description]}"
      end
      opts.separator ''
      opts.separator 'See k8s-harness [subcommand] --help for more specific options.'
      opts.separator ''
      opts.separator 'Global options:'
      opts.on('-d', '--debug', 'Show debug output') do
        add_option(options: { enable_debug_logging: true })
      end
      opts.on('-h', '--help', 'Displays this help message') do
        add_option(options: { help: opts.help })
      end
    end

    def self.parse(args)
      args.push('-h') if args.empty? || subcommands_missing?(args)
      @base_command.order!(args)
      subcommand = args.shift
      if subcommand.nil?
        puts @options[:base][:help]
      else
        enable_debug_logging_if_present
        @subcommands[subcommand.to_sym][:option_parser].order!(args)
        call_entrypoint(subcommand)
      end
    end

    def self.enable_debug_logging_if_present
      KubernetesHarness::Logging.enable_debug_logging if @options[:base][:enable_debug_logging]
    end

    def self.subcommands_missing?(args)
      args.select { |arg| arg.match?(/^[a-z]/) }.empty?
    end

    def self.add_option(options:, subcommand: nil)
      if subcommand.nil?
        @options[:base].merge!(options)
      else
        @options[subcommand] = {} unless @options.key subcommand
        @options[subcommand].merge!(options)
      end
    end

    def self.call_entrypoint(subcommand)
      KubernetesHarness::Subcommand.method(subcommand.to_sym).call(@options[subcommand.to_sym])
    end

    private_class_method :call_entrypoint, :add_option, :subcommands_missing?
  end
end
