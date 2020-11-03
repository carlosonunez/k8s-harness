#!/usr/bin/env bash

usage() {
  cat <<-USAGE
$(basename $0)
Ensures that the GitHub Actions runner we are using is configured properly.

OPTIONS

  -f, --force           Run this script regardless of whether we're in CI or not.
USAGE
}

show_info() {
  >&2 printf "\033[1;32m--> [INFO]\033[m $1\n"
}

show_error() {
  >&2 printf "\033[1;31m--> [ERROR]\033[m $1\n"
}

see_if_we_can_download_boxes() {
  # Vagrant kept bombing in integration due to boxes not being pulled correctly.
  # Let's try to download the boxes we need to run our integration tests ahead of them
  # executing.
  show_info "Checking if we can download and unzip Vagrant boxes."
  vagrant_boxes_used_by_k8s_harness=$(cat "$(dirname $0)/../include/Vagrantfile" |
    grep config.vm.box |
    sed 's/.*config.vm.box = "\(.*\)"$/\1/'
  )
  for box in $vagrant_boxes_used_by_k8s_harness
  do
    vagrant box add "$box" --force
  done
}

ensure_ci_or_force_run_enabled() {
  test "$CI" == "true" || \
    (echo "$*" | grep -wq -- '-f') || \
    (echo "$*" | grep -wq -- '--force')
}

show_diagnostics() {
  consumed_disk_space() {
    du -sh "$PWD"
  }

  free_disk_space() {
    df -h "$PWD"
  }

  echo "Here are some helpful diagnostics:"
  cat <<-DIAGNOSTICS
    Diagnostic info
    ====================

    Consumed disk space
    --------------------
    $(consumed_disk_space)

    Free disk space
    ----------------
    $(free_disk_space)
DIAGNOSTICS
}

if [ "$1" == '-h' ] || [ "$1" == '--help' ]
then
  usage
  exit 0
fi

if [ "$1" == '-v' ] || [ "$1" == '--version' ]
then
  printf "$(basename $0) version $(cat $(dirname $0)/../VERSION)"
  exit 0
fi

if ! ensure_ci_or_force_run_enabled $*
then
  show_error "This script only runs in CI environments. \
Add \033[1;36m[-f | --force]\033[m to override this."
  exit 1
fi

if ! { see_if_we_can_download_boxes; }
then
  show_error "Integration environment is broken. Please re-run this on another runner."
  show_diagnostics
  exit 1
fi
