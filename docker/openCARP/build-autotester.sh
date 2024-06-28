#!/bin/bash
set -euo pipefail;

build_autotester() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${autotester_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${autotester_branch}" \
      "${autotester_repo_url}" \
      "${autotester_src_dir}";
    apt update;
    apt -y --no-install-recommends install \
      libxml2-dev pandoc libxml2-utils xsltproc;
  fi
  cd "${autotester_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${autotester_prefix}" "./build";
  mkdir -p "./build";
  cd "./build";
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja .. \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_BUILD_TYPE=Release;
  ninja -j $(nproc);
  mkdir -p "${autotester_prefix}";
  mv -f "${PWD}/autotester" "${autotester_prefix}/.";
}

build_autotester;
