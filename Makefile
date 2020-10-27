#!/usr/bin/env make
MAKEFLAGS += --silent
SHELL := /usr/bin/env bash
ROOTDIR := $(shell git rev-parse --show-toplevel)

.PHONY: is_rvm_installed \
	create_env \
	recreate_env \
	delete_env \
	install_rvm \
	test


is_rvm_installed:
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
		source ~/.rvm/scripts/rvm && \
		rvm --quiet use && \
		bundle install --quiet; \
	fi

recreate_env:
	source ~/.rvm/scripts/rvm && \
	rvm --quiet use && \
	bundle install --quiet;

delete_env:
	rvm --force gemset delete k8s-harness

install_rvm:
	source ~/.rvm/scripts/rvm && \
		rvm --version &>/dev/null || curl -sSL https://get.rvm.io | bash -s stable --ruby

test: is_rvm_installed create_env
test:
	rspec -I $(ROOTDIR)/tests -I $(ROOTDIR)/lib --tag ~@wip --fail-fast --format documentation tests/
