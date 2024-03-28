#!/bin/bash
set -euo pipefail;

build_mpich() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  python_runtime_env;
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
  libfabric_runtime_env;
  local type="${2:-${gcc_type}}";
  local poly="${3:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cudac="$(which nvcc)";
  local cudaflags="-arch=sm_${cuda_arch}";
  local fortran="/usr/bin/gfortran";
  local fcflags="${cflags}";
  local ldflags="";
  if [ "${type}" == "${llvm_type}" ];
  then
    llvm_runtime_env;
    cc="$(llvm-config --bindir)/clang";
    cflags+=" -Wno-unused-but-set-variable";
    cxx="$(llvm-config --bindir)/clang++";
    cxxflags+=" -Wno-unused-but-set-variable";
    cudac="${cxx}";
    cudaflags=" --cuda-gpu-arch=sm_${cuda_arch} -lcudart_static -ldl -lrt -pthread";
    if [ "${poly}" == "ON" ];
    then
      cflags+=" ${polly_cflags}";
      cxxflags+=" ${polly_cxxflags}";
      fflags+=" ${graphite_cflags}";
    fi
    type+="-${poly}-$(llvm-config --version)"
  else
    if [ "${poly}" == "ON" ];
    then
      cflags+=" ${graphite_cflags}";
      cxxflags+=" ${graphite_cxxflags}";
      fflags="${cflags}";
    fi
    type+="-${poly}-$(${cc} --version | awk '/^gcc/{print $4}')"
  fi
  if [ ! -d "${mpich_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${mpich_branch}" \
      "${mpich_repo_url}" \
      "${mpich_src_dir}";
  fi
  cd "${mpich_src_dir}";
  git pull --recurse-submodules;
  ./autogen.sh;
  rm -rf "${mpich_prefix}" \
    "./build";
  mkdir -p "./build";
  cd "./build";
  ../configure \
    CC="${cc}" \
    CFLAGS="${cflags}" \
    CXX="${cxx}" \
    CXXFLAGS="${cxxflags}" \
    CUDAC="${cudac}" \
    CUDAFLAGS="${cudaflags}" \
    FC="${fortran}" \
    FCFLAGS="${fcflags}" \
    LDFLAGS="${ldflags}" \
    --prefix="${mpich_prefix}" \
    --with-hwloc="${hwloc_prefix}" \
    --with-libfabric="${libfabric_prefix}" \
    --with-ucx="${ucx_prefix}" \
    --with-cuda="${CUDA_HOME}" \
    --enable-fast=all,O3;
  make -j $(nproc);
  make check;
  make install;
  return ${?};
}

build_mpich "${@}";
