#!/bin/bash
set -euo pipefail;

unpatch() {
  if [ -f "${parmetis_src_dir}/programs/CMakeLists.txt.orig" ];
  then
    mv "${parmetis_src_dir}/programs/CMakeLists.txt.orig" \
      "${parmetis_src_dir}/programs/CMakeLists.txt";
  fi
}

build_parmetis() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  cuda_runtime_env;
  hwloc_runtime_env;
  ucx_runtime_env;
  mpi_impl_runtime_env "${mpi_impl}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${gklib_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${gklib_branch}" \
      "${gklib_repo_url}" \
      "${gklib_src_dir}";
  fi
  cd "${gklib_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${gklib_prefix}";
  make config cc="${cc}" prefix="${gklib_prefix}" shared=1 openmp=set;
  make;
  make install;
  if [ ! -d "${metis_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${metis_branch}" \
      "${metis_repo_url}" \
      "${metis_src_dir}";
  fi
  cd "${metis_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${metis_prefix}";
  make config cc="${cc}" prefix="${metis_prefix}" gklib_path="${gklib_prefix}" shared=1 openmp=set;
  make;
  make install;
  if [ ! -d "${parmetis_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${parmetis_branch}" \
      "${parmetis_repo_url}" \
      "${parmetis_src_dir}";
  fi
  cd "${parmetis_src_dir}";
  git pull --recurse-submodules;
  unpatch;
  local patch_dir="${dev_home}/ParMETIS/${parmetis_branch}";
  patch -b "${parmetis_src_dir}/programs/CMakeLists.txt" \
    "${patch_dir}/programs/CMakeLists.txt.patch";
  parmetis_prefix+="/${mpi_impl}";
  rm -rf "${parmetis_prefix}";
  CFLAGS="$(pkg-config ${PKG_MPI_NAME} --cflags-only-I)" LDFLAGS="$(pkg-config ${PKG_MPI_NAME} --libs-only-L)" make config cc="${cc}" prefix="${parmetis_prefix}" metis_path="${metis_prefix}" gklib_path="${gklib_prefix}" shared=1 openmp=set;
  make;
  make install;
  unpatch;
  return ${?};
}

build_parmetis "${@}";
