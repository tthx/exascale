#!/bin/bash
set -euo pipefail;

# ERROR: One test failed: "FAIL: hwloc_get_area_memlocation"
build_hwloc() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  cuda_runtime_env;
  local type="${2:-${gcc_type}}";
  local poly="${3:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cudac="$(which nvcc)";
  local cudaflags="-arch=sm_${cuda_arch}";
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
  if [ ! -d "${hwloc_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${hwloc_branch}" \
      "${hwloc_repo_url}" \
      "${hwloc_src_dir}";
  fi
  cd "${hwloc_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${hwloc_prefix}";
  ./autogen.sh;
  ./configure \
    CC="${cc}" \
    CFLAGS="${cflags}" \
    CXX="${cxx}" \
    CXXFLAGS="${cxxflags}" \
    CUDAC="${cudac}" \
    CUDACXX="${cudac}" \
    CUDAFLAGS="${cudaflags}" \
    LDFLAGS="${ldflags}" \
    --prefix="${hwloc_prefix}" \
    --with-cuda="${CUDA_HOME}";
  make -j $(nproc) all;
  make check;
  make install;
  return ${?};
}

build_hwloc "${@}";
