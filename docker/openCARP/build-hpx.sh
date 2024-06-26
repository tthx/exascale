#!/bin/bash
set -euo pipefail;

build_hpx() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  python_runtime_env;
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
  libfabric_runtime_env;
  mpi_impl_runtime_env "${mpi_impl}";
  lci_runtime_env "${mpi_impl}";
  boost_runtime_env "${mpi_impl}";
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
  if [ ! -d "${hpx_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${hpx_branch}" \
      "${hpx_repo_url}" \
      "${hpx_src_dir}";
  fi
  cd "${hpx_src_dir}";
  git pull --recurse-submodules;
  hpx_prefix+="/${mpi_impl}";
  rm -rf "${hpx_prefix}" "./build";
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
    -DCMAKE_CUDA_COMPILER="${cudac}" \
    -DCMAKE_CUDA_ARCHITECTURES="${cuda_arch}" \
    -DCMAKE_CUDA_FLAGS="${cudaflags}" \
    -DCUDA_STANDARD="${cxx_dialect}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_INSTALL_PREFIX="${hpx_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DHPX_WITH_CXX_STANDARD="${cxx_dialect}" \
    -DHPX_WITH_CUDA=ON \
    -DHPX_WITH_PARCELPORT_LCI=ON \
    -DHPX_WITH_PARCELPORT_LIBFABRIC=OFF \
    -DHPX_WITH_PARCELPORT_MPI=ON \
    -DHPX_WITH_DEPRECATION_WARNINGS=OFF \
    -DHPX_WITH_EXAMPLES=ON \
    -DHPX_WITH_TESTS=ON \
    -DHPX_WITH_TOOLS=ON;
  ninja -j $(nproc);
  ninja -j $(nproc) tests;
  ninja install;
  return ${?};
}

build_hpx "${@}";
