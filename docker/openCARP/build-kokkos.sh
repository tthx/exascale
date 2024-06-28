#!/bin/bash
set -euo pipefail;

# ERROR: 4.2.01, Tests:
#   - Kokkos_CoreUnitTest_Cuda2 (Failed)

#[ RUN      ] cuda.view_64bit
#unknown file: Failure
#C++ exception with description "Kokkos failed to allocate memory for label "A".  Allocation using MemorySpace named "Cuda" failed with the following error:  Allocation of size 4.657 G failed, likely due to insufficient memory.  (The allocation mechanism was cudaMalloc().  The Cuda allocation returned the error code "cudaErrorMemoryAllocation".)
#" thrown in the test body.
#[  FAILED  ] cuda.view_64bit (32 ms)

#[ RUN      ] cuda.view_allocation_large_rank
#unknown file: Failure
#C++ exception with description "Kokkos failed to allocate memory for label "v".  Allocation using MemorySpace named "Cuda" failed with the following error:  Allocation of size 4 G failed, likely due to insufficient memory.  (The allocation mechanism was cudaMalloc().  The Cuda allocation returned the error code "cudaErrorMemoryAllocation".)
#" thrown in the test body.
#[  FAILED  ] cuda.view_allocation_large_rank (173 ms)

#----------] Global test environment tear-down
#[==========] 122 tests from 3 test suites ran. (22951 ms total)
#[  PASSED  ] 120 tests.
#[  FAILED  ] 2 tests, listed below:
#[  FAILED  ] cuda.view_64bit
#[  FAILED  ] cuda.view_allocation_large_rank

build_kokkos() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  cuda_runtime_env;
  hwloc_runtime_env;
  local type="${2:-${llvm_type}}";
  local poly="${3:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${4:-17}";
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
  if [ ! -d "${kokkos_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${kokkos_branch}" \
      "${kokkos_repo_url}" \
      "${kokkos_src_dir}";
  fi
  cd "${kokkos_src_dir}";
  git pull --recurse-submodules;
  #patch -b "${kokkos_src_dir}/core/src/HPX/Kokkos_HPX.hpp" \
    #"${dev_home}/kokkos/${kokkos_branch}/core/src/HPX/Kokkos_HPX.hpp.patch";
  rm -rf "${kokkos_prefix}" "./build";
  mkdir "./build";
  cd "./build";
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXX="${cxx}";
  export CXXFLAGS="${cxxflags}";
  export CUDAC="${cudac}"
  export CUDACXX="${cudac}";
  export CUDAFLAGS="${cudaflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja .. \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_CXX_STANDARD="${cxx_dialect}" \
    -DCMAKE_CUDA_COMPILER="${cudac}" \
    -DCMAKE_CUDA_ARCHITECTURES="${cuda_arch}" \
    -DCMAKE_CUDA_FLAGS="${cudaflags}" \
    -DCUDA_STANDARD="${cxx_dialect}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_INSTALL_PREFIX="${kokkos_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DKokkos_ENABLE_SERIAL=ON \
    -DKokkos_ENABLE_OPENMP=ON \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkos_ENABLE_AGGRESSIVE_VECTORIZATION=ON \
    -DKokkos_ENABLE_EXAMPLES=ON \
    -DKokkos_ENABLE_LARGE_MEM_TESTS=ON \
    -DKokkos_ENABLE_TESTS=ON \
    -DKokkos_ENABLE_TUNING=ON \
    -DHWLOC_INCLUDE_DIRS="${hwloc_prefix}/include" \
    -DHWLOC_LIBRARY="${hwloc_prefix}/lib/libhwloc.so" \
    -DKokkos_ENABLE_HWLOC=ON \
    -DKokkos_ARCH_NATIVE=ON;
    #-DHPX_DIR="${hpx_prefix}" \
  ninja -j $(nproc);
  OMP_PROC_BIND=spread \
  OMP_PLACES=threads \
  ninja -j $(nproc) test;
  ninja install;
  #mv "${kokkos_src_dir}/core/src/HPX/Kokkos_HPX.hpp.orig" \
    #"${kokkos_src_dir}/core/src/HPX/Kokkos_HPX.hpp";
  return ${?};
}

build_kokkos "${@}";
