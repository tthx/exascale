#!/bin/bash
set -euo pipefail;

build_libfabric() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
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
  if [ ! -d "${libfabric_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${libfabric_branch}" \
      "${libfabric_repo_url}" \
      "${libfabric_src_dir}";
  fi
  cd "${libfabric_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${libfabric_prefix}";
  export CC="${cc}";
  export CFLAGS="${cflags} -I${ucx_prefix}/include -I${CUDA_HOME}/include";
  export CXX="${cxx}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  export LIBS="-L${ucx_prefix}/lib -lucp -luct -lucm -lucs -L${CUDA_HOME}/lib64 -lcudart -L${CUDA_HOME}/lib64/stubs -lcuda -lnvidia-ml";
  ./autogen.sh;
  ./configure \
    --prefix="${libfabric_prefix}" \
    --enable-ucx=yes \
    --with-cuda="${CUDA_HOME}";
  make -j $(nproc);
  make check;
  make install;
  return ${?};
}

build_libfabric "${@}";
