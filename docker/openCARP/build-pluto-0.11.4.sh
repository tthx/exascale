#!/bin/bash
set -euo pipefail;

build_pluto() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${pluto_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${pluto_branch}" \
      "${pluto_repo_url}" \
      "${pluto_src_dir}";
  fi
  cd "${pluto_src_dir}";
  rm -rf "${pluto_prefix}";
  ./autogen.sh;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  ./configure \
    --prefix="${pluto_prefix}";
  make clean;
  make -j $(nproc) all;
  make test;
  make install;
  cp -rf "${pluto_src_dir}/orio-0.1.0" \
    "${pluto_prefix}/.";
  cp -rf "${pluto_src_dir}/annotations" \
    "${pluto_prefix}/.";
  cp -f "${pluto_src_dir}/plann" \
    "${pluto_prefix}/bin/.";
  cp -f "${dev_home}/pluto/inscop-0.11.4" \
    "${pluto_prefix}/bin/inscop";
  cp -f "${dev_home}/pluto/polycc-0.11.4" \
    "${pluto_prefix}/bin/polycc";
  return ${?};
}

build_pluto;
