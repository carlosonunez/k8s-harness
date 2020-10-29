# frozen_string_literal: true

module KubernetesHarness
  module Clusters
    # Just constants.
    module Constants
      MASTER_NODE_NAME = 'k3s-node-0'
      WORKER_NODE_NAMES = ['k3s-node-1'].freeze
      DOCKER_REGISTRY_NAME = 'k3s-registry'
      IP_ETH1_COMMAND =
        "\"ip addr show dev eth1 | grep \'\\<inet\\>\' | awk \'{print \\$2}\' | cut -f1 -d \'/\'\""
      ALL_NODES = [MASTER_NODE_NAME, WORKER_NODE_NAMES, DOCKER_REGISTRY_NAME].flatten
    end
  end
end
