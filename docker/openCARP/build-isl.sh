#!/bin/bash
set -euo pipefail;

build_isl() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  . "${script_dir}/runtime-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${isl_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${isl_branch}" \
      "${isl_repo_url}" \
      "${isl_src_dir}";
  fi
  cd "${isl_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${isl_prefix}";
  ./autogen.sh;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  export LIBS="$(llvm-config --ldflags) -lclangASTMatchers";
  ./configure \
    --prefix="${isl_prefix}" \
    --with-clang-prefix="$(llvm-config --prefix)";
  make clean;
  make -j $(nproc) all;
  make install;
  return ${?};
}

build_isl;
