# frozen_string_literal: true

require 'fileutils'
require 'k8s_harness/paths'

module KubernetesHarness
  # This module is for everything around CRUD'ing disposable clusters.
  module Clusters
    # k8s-harness relies on storing things like Ansible playbooks for our
    # disposable cluster and extra files that users might use.
    # This module handles all of that.
    module Metadata
      def self.default_dir
        "#{ENV['PWD']}/.k8sharness_data"
      end

      def self.create_dir!
        ::FileUtils.mkdir_p default_dir unless Dir.exist? default_dir
      end

      def self.initialize!
        create_dir!
        FileUtils.cp_r("#{KubernetesHarness::Paths.include_dir}/.", default_dir)
      end
    end
  end
end
