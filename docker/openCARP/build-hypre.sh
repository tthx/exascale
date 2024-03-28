#!/bin/bash
set -euo pipefail;

# ALERT: No tests provides with cmake
build_hypre() {
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
  superlu_dist_runtime_env "${mpi_impl}";
  kokkos_runtime_env;
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
  if [ ! -d "${hypre_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${hypre_branch}" \
      "${hypre_repo_url}" \
      "${hypre_src_dir}";
  fi
  cd "${hypre_src_dir}";
  git pull --recurse-submodules;
  cd "./src";
  hypre_prefix+="/${mpi_impl}";
  rm -rf "${hypre_prefix}" "./build";
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
    -DCMAKE_INSTALL_PREFIX="${hypre_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DHYPRE_ENABLE_SHARED=ON \
    -DHYPRE_ENABLE_HYPRE_BLAS=OFF \
    -DHYPRE_ENABLE_HYPRE_LAPACK=OFF \
    -DHYPRE_WITH_GPU_AWARE_MPI=ON \
    -DHYPRE_WITH_OPENMP=ON \
    -DHYPRE_WITH_DSUPERLU=ON \
    -DTPL_DSUPERLU_LIBRARIES="-L${superlu_dist_prefix}/${mpi_impl}/lib -lsuperlu_dist" \
    -DTPL_DSUPERLU_INCLUDE_DIRS="${superlu_dist_prefix}/${mpi_impl}/include" \
    -DHYPRE_PRINT_ERRORS=ON \
    -DHYPRE_TIMING=ON \
    -DHYPRE_BUILD_EXAMPLES=ON \
    -DHYPRE_BUILD_TESTS=ON \
    -DHYPRE_WITH_CUDA=ON \
    -DHYPRE_CUDA_SM="${cuda_arch}" \
    -DHYPRE_ENABLE_UNIFIED_MEMORY=ON \
    -DHYPRE_ENABLE_DEVICE_MALLOC_ASYNC=ON \
    -DHYPRE_ENABLE_CUSOLVER=ON \
    -DHYPRE_ENABLE_DEVICE_POOL=ON \
    -DHYPRE_ENABLE_CUBLAS=ON;
  ninja -j $(nproc);
  ./src/test/runtest.sh;
  ninja install;
  return 0;
}

build_hypre "${@}";
