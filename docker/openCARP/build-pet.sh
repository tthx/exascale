#!/bin/bash
set -euo pipefail;

build_pet() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  . "${script_dir}/runtime-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${pet_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${pet_branch}" \
      "${pet_repo_url}" \
      "${pet_src_dir}";
  fi
  cd "${pet_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${pet_prefix}";
  ./autogen.sh;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  export LIBS="$(llvm-config --ldflags) -lclangSupport -lclangBasic";
  ./configure \
    --prefix="${pet_prefix}" \
    --with-isl-prefix="${isl_prefix}" \
    --with-clang-prefix="$(llvm-config --prefix)";
  make clean;
  make -j $(nproc) all;
  make -j $(nproc) pet pet_scop_cmp;
  make install;
  cp -f .libs/pet .libs/pet_scop_cmp \
    .libs/pet_check_code .libs/pet_codegen .libs/pet_loopback \
    "${pet_prefix}/bin/.";
  return ${?};
}

build_pet;
