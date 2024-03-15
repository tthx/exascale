#!/bin/bash
set -euo pipefail;

build_osl() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${osl_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${osl_branch}" \
      "${osl_repo_url}" \
      "${osl_src_dir}";
  fi
  cd "${osl_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${osl_prefix}";
  ./autogen.sh;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  ./configure --prefix="${osl_prefix}";
  make -j $(nproc);
  make -j $(nproc) test;
  make install;
  return ${?};
}

build_osl;
