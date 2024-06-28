#!/bin/bash
set -euo pipefail;

build_starpu() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
  mpi_impl_runtime_env "${mpi_impl}";
  local type="${3:-${gcc_type}}";
  local poly="${4:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${5:-17}";
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
  if [ ! -d "${starpu_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${starpu_branch}" \
      "${starpu_repo_url}" \
      "${starpu_src_dir}";
  fi
  cd "${starpu_src_dir}";
  git pull --recurse-submodules;
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXX="${cxx}";
  export CXXFLAGS="${cxxflags}";
  export CUDAC="${cudac}"
  export CUDACXX="${cudac}";
  export CUDAFLAGS="${cudaflags}";
  export LDFLAGS="${ldflags}";
  ./configure \
    --prefix="${starpu_prefix}" \
    -enable-data-locality-enforce \
    -enable-blocking-drivers \
    -enable-worker-callbacks \
    -enable-starpupy \
    -enable-mpi \
    -enable-mpi-pedantic-isend \
    -enable-mpi-ft \
    -enable-mpi-ft-stats \
    -enable-mpi-master-slave \
    -enable-nmad \
    -enable-openmp \
    -enable-openmp-llvm \
    -enable-bubble \
    -enable-parallel-worker \
    -enable-perf-debug \
    -enable-model-debug \
    -enable-fxt-lock \
    -enable-maxbuffers \
    -enable-allocation-cache \
    -enable-opengl-render \
    -enable-memory-stats \
    -enable-simgrid \
    -enable-calibration-heuristic;
  make -j $(nproc);
  return ${?};
}

build_starpu "${@}";
