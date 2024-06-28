#!/bin/bash
set -euo pipefail;

get_cmake() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh" && \
  wget -q "${cmake_file}" -O /tmp/cmake.tgz && \
  tar xzf /tmp/cmake.tgz --one-top-level="${cmake_prefix}" \
    --strip-components 1 && \
  rm -f /tmp/cmake.tgz;
  return ${?};
}

get_cmake;
