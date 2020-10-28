# frozen_string_literal: true

module KubernetesHarness
  # The canonical source of all toplevel paths
  module Paths
    def self.root_dir
      File.expand_path '../..', __dir__
    end

    def self.include_dir
      File.join root_dir, 'include'
    end
  end
end
