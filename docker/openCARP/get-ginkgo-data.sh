#!/bin/bash
set -euo pipefail;

unpatch() {
  if [ -f "${HOME}/.local/bin/ssget.orig" ];
  then
    mv -f "${HOME}/.local/bin/ssget.orig" \
      "${HOME}/.local/bin/ssget";
  fi
}

get_ginkgo_data() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  if [ ! -d "${ssget_src_dir}" ];
  then
    git clone \
      --recursive \
      -b "${ssget_branch}" \
      "${ssget_repo_url}" \
      "${ssget_src_dir}";
  fi
  cp -f "${ssget_src_dir}/ssget" \
    "${HOME}/.local/bin/ssget";
  unpatch;
  patch -b "${HOME}/.local/bin/ssget" \
    "${dev_home}/ginkgo/ssget.patch";
  for i in $(seq 1 $(ssget -n));
  do
    ssget -f -i "${i}";
  done
  unpatch;
  return ${?};
}

get_ginkgo_data "${@}";
