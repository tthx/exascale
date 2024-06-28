#!/bin/bash
set -euo pipefail;

# ERROR: At least "sparse/unit_test/backends/Test_Cuda_Sparse.cpp" compilation failed.
build_kokkos_kernels() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  cuda_runtime_env;
  hwloc_runtime_env;
  kokkos_runtime_env;
  local type="${2:-${llvm_type}}";
  local poly="${3:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${4:-17}";
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
  if [ ! -d "${kokkos_kernels_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${kokkos_kernels_branch}" \
      "${kokkos_kernels_repo_url}" \
      "${kokkos_kernels_src_dir}";
  fi
  cd "${kokkos_kernels_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${kokkos_kernels_prefix}" "./build";
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
    -DCMAKE_INSTALL_PREFIX="${kokkos_kernels_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DKokkos_ENABLE_SERIAL=ON \
    -DKokkos_ENABLE_OPENMP=ON \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkosKernels_ENABLE_TPL_BLAS=ON \
    -DKokkosKernels_ENABLE_EXAMPLES=OFF \
    -DKokkosKernels_ENABLE_TESTS=OFF;
  ninja -j $(nproc);
  OMP_PROC_BIND=spread \
  OMP_PLACES=threads \
  ninja -j $(nproc) test;
  ninja install;
  return ${?};
}

build_kokkos_kernels "${@}";
