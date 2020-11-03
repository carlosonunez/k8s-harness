#!/usr/bin/env make
MAKEFLAGS += --silent
SHELL := /usr/bin/env bash
ROOTDIR := $(shell git rev-parse --show-toplevel)
ifeq ($(CI),true)
VAGRANT_HOME := $(PWD)/.vagrant_home
VAGRANT_DOTFILE_PATH := $(PWD)/.vagrant_dotfile_path
else
VAGRANT_HOME := $(HOME)/.vagrant.d
VAGRANT_DOTFILE_PATH := $(HOME)/.vagrant
endif


.PHONY: is_rvm_installed \
	create_env \
	recreate_env \
	delete_env \
	install_rvm \
	test


is_rvm_installed:
	if test "$(CI)" == "true"; \
	then \
		>&2 echo "INFO: Running in CI; no RVM required."; \
		exit 0; \
	fi; \
	if ! rvm --version &>/dev/null; \
	then \
		>&2 echo "ERROR: rvm is not installed. Install it by running this: \
make install_rvm"; \
		exit 1; \
	fi

create_env:
	if ! ( echo "$(GEM_HOME)" | grep -q 'k8s-harness' ) || \
		! ( find "$(GEM_HOME)/gems" -type d -maxdepth 1 | grep -qi rspec ); \
	then \
		if test "$(CI)" != "true"; \
		then \
			source ~/.rvm/scripts/rvm && \
			rvm --quiet use; \
			gem install bundler --quiet; \
			bundle install --quiet; \
		else  \
			gem install bundler; \
			bundle install; \
		fi; \
		gem which rspec; \
	fi

recreate_env:
	{ test "$(CI)" == "true" || source ~/.rvm/scripts/rvm && rvm --quiet use; }; \
	{ test "$(CI)" == "true" && bundle install || bundle install --quiet };

delete_env:
	test "$(CI)" == "true" && { >&2 echo "INFO: In CI. Nothing to delete."; exit 0; }; \
	rvm --force gemset delete k8s-harness

deploy: build
deploy:
	if test -z "$(GEM_HOST_API_KEY)"; \
	then \
		>&2 echo "ERROR: Please define GEM_HOST_API_KEY before deploying."; \
		exit 1; \
	fi; \
	gem push output/k8s_harness.gem

install_rvm:
	test "$(CI)" == "true" && { >&2 echo "INFO: In CI. rvm not required."; exit 0; }; \
	source ~/.rvm/scripts/rvm && \
		rvm --version &>/dev/null || curl -sSL https://get.rvm.io | bash -s stable --ruby

ensure_version: ensure_version_diff ensure_version_tag

ensure_version_diff:
	if test -z "$$(git diff HEAD..HEAD~1 VERSION)"; \
	then \
		>&2 echo 'ERROR: The VERSION file seems to not have been updated?'; \
		exit 1; \
	fi

ensure_version_tag:
	this_commit=$$(git rev-parse HEAD); \
	version_tag_matching_commit=$$(git show-ref --tags | grep $$this_commit); \
	if test -z "$$version_tag_matching_commit"; \
	then \
		>&2 echo 'ERROR: The HEAD commit does not have a tag. Fix this.'; \
		exit 1; \
	fi; \
	this_version=$$(cat VERSION); \
	version_from_version_tag=$$(echo "$$version_tag_matching_commit" | \
		awk '{print $$2}' | \
		rev | \
		cut -f1 -d "/" | \
		rev); \
	if test "$$this_version" != "$$version_from_version_tag"; \
	then \
		>&2 echo "ERROR: Expected [$$this_version] in this version tag, but found [$$version_from_version_tag]."; \
		exit 1; \
	fi

test: is_rvm_installed create_env
test:
	bundle exec rspec -I $(ROOTDIR)/tests -I $(ROOTDIR)/lib \
		--tag ~@wip \
		--tag ~@integration \
		--fail-fast \
		--format \
		documentation tests/

build: is_rvm_installed
build:
	mkdir -p output; \
	if test "$(CI)" == "true"; \
	then \
		gem build -o output/k8s_harness.gem k8s_harness.gemspec && \
			gem install output/k8s_harness.gem; \
	else \
		gem build --quiet --silent -o output/k8s_harness.gem k8s_harness.gemspec && \
			gem install --quiet --silent output/k8s_harness.gem; \
	fi;

test_verbose: is_rvm_installed create_env
test_verbose:
	LOG_LEVEL=DEBUG bundle exec rspec -I $(ROOTDIR)/tests -I $(ROOTDIR)/lib \
						--tag ~@wip \
						--tag ~@integration\
						--fail-fast \
						--format documentation tests/

test_debug: test_verbose

integration: is_rvm_installed create_env build verify_runner_doesnt_suck
integration:
	cp tests/integration/.k8sharness .; \
	VAGRANT_HOME="$(VAGRANT_HOME)" \
		VAGRANT_DOTFILE_PATH="$(VAGRANT_DOTFILE_PATH)" \
		bundle exec rspec -I $(ROOTDIR)/tests -I $(ROOTDIR)/lib --tag @integration --fail-fast \
		--format documentation \
		tests/integration
	
integration_verbose: is_rvm_installed create_env build verify_runner_doesnt_suck
integration_verbose:
	cp tests/integration/.k8sharness .; \
	VAGRANT_HOME="$(VAGRANT_HOME)" \
		VAGRANT_DOTFILE_PATH="$(VAGRANT_DOTFILE_PATH)" \
		LOG_LEVEL=DEBUG \
		bundle exec rspec -I $(ROOTDIR)/tests -I $(ROOTDIR)/lib --tag @integration --fail-fast \
		--format documentation \
		tests/integration

integration_debug: integration_verbose

verify_runner_doesnt_suck:
	VAGRANT_HOME="$(VAGRANT_HOME)" \
		VAGRANT_DOTFILE_PATH="$(VAGRANT_DOTFILE_PATH)" \
		./scripts/verify_runner_doesnt_suck.sh
