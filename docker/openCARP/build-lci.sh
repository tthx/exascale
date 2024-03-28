#!/bin/bash
set -euo pipefail;

build_lci() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  python_runtime_env;
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
  libfabric_runtime_env;
  mpi_impl_runtime_env "${mpi_impl}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${2:-17}";
  local ldflags="";
  if [ ! -d "${lci_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${lci_branch}" \
      "${lci_repo_url}" \
      "${lci_src_dir}";
  fi
  cd "${lci_src_dir}";
  git pull --recurse-submodules;
  lci_prefix+="/${mpi_impl}";
  rm -rf "${lci_prefix}" "./build";
  mkdir "./build";
  cd "./build";
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXX="${cxx}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja .. \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_CXX_STANDARD="${cxx_dialect}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_INSTALL_PREFIX="${lci_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLCI_SERVER=ofi;
  ninja -j $(nproc);
  ninja -j $(nproc) test;
  ninja install;
  return ${?};
}

build_lci "${@}";
