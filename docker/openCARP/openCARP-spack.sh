#!/bin/bash
set -euo pipefail;

get_spack() {
  if [ ! -d "${spack_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${spack_branch}" \
      -c feature.manyFiles=true \
      "${spack_repo_url}" \
      "${spack_src_dir}";
  fi
  cd "${spack_src_dir}";
  git pull --recurse-submodules;
  return ${?};
}

add_solverstack_spack_repo() {
  if [ ! -d "${solverstack_spack_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      "${solverstack_spack_repo_url}" \
      "${solverstack_spack_src_dir}";
  fi
  cd "${solverstack_spack_src_dir}";
  git pull --recurse-submodules;
  if [ -z "$(spack repo list|grep "${solverstack_spack_src_dir}")" ];
  then
    spack repo add "${solverstack_spack_src_dir}";
  fi
  return ${?};
}

openCARP_spack() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  local compiler="%${3:-"gcc"}";
  local cxxstd="${4:-"17"}";
  local cuda_version="${5:-11.8}";
  local gdrcopy_version="2.3"; # because the recommanded version (e.g. 2.4.1) failed to be patched
  cuda_runtime_env;
  llvm_runtime_env;
  get_spack;
  . "${spack_src_dir}/share/spack/setup-env.sh";
  spack compiler find;
  env_name+="-${mpi_impl}";
  if [ -n "$(spack env list|grep "${env_name}")" ];
  then
    spack env remove -y "${env_name}";
  fi
  spack env create "${env_name}";
  spack clean -a;
  spack env activate "${env_name}";
  spack install --add cuda@"${cuda_version}" "${compiler}";
  # spack install --add llvm@"${llvm_version}" "${compiler}" \
  #   +mlir +python targets="x86,nvptx" openmp=project \
  #   +cuda cuda_arch="${cuda_arch}";
  spack install --add gdrcopy@"${gdrcopy_version}" "${compiler}" \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add libpciaccess "${compiler}";
  spack install --add hwloc "${compiler}" +libudev \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add pmix "${compiler}";
  spack install --add xpmem "${compiler}" -kernel-module;
  spack install --add rdma-core "${compiler}" -man_pages;
  spack install --add ucx "${compiler}" \
    +assertions +cma +dc +dm +ib_hw_tm +parameter_checking +rc +rdmacm \
    +thread_multiple +ucg +ud +verbs +xpmem +gdrcopy \
    +cuda cuda_arch="${cuda_arch}";
  case "${mpi_impl}" in
    "openmpi")
      spack install --add openmpi "${compiler}" \
        fabrics=cma,ofi,ucx,verbs,xpmem +openshmem \
        +cuda cuda_arch="${cuda_arch}";
      ;;
    "mpich")
      spack install --add libunwind "${compiler}" \
        +block_signals +conservative_checks +cxx_exceptions \
        -docs +pic +xz +zlib;
      spack install --add argobots "${compiler}" +affinity +stackunwind +tool;
      spack install --add yaksa "${compiler}" +cuda cuda_arch="${cuda_arch}";
      spack install --add libzmq "${compiler}" +libunwind;
      spack install --add slurm "${compiler}" +cgroup +hwloc +mariadb \
        +nvml +pmix;
      spack install --add mpich "${compiler}" netmod=ucx +slurm +verbs \
        +cuda cuda_arch="${cuda_arch}";
      ;;
  esac
  spack install --add metis "${compiler}";
  spack install --add parmetis "${compiler}" +shared;
  spack install --add scotch "${compiler}" +shared +esmumps +mpi_thread;
  spack install --add openblas "${compiler}" +shared threads=openmp -fortran;
  spack install --add blaspp "${compiler}" +shared \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add lapackpp "${compiler}" +shared \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add superlu-dist@develop "${compiler}" +shared \
    +openmp +cuda cuda_arch="${cuda_arch}";
  spack install --add hypre@develop "${compiler}" +shared +superlu-dist \
    +openmp +unified-memory +cuda cuda_arch="${cuda_arch}";
  spack install --add random123 "${compiler}";
  spack install --add slate "${compiler}" +shared \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add strumpack "${compiler}" +shared \
    +slate +cuda cuda_arch="${cuda_arch}";
  spack install --add hpddm@main "${compiler}";
  spack install --add hpx@master "${compiler}" \
    cxxstd="${cxxstd}" +examples +tools +generic_coroutines malloc=mimalloc \
    instrumentation=valgrind +async_mpi networking=mpi \
    +async_cuda +cuda cuda_arch="${cuda_arch}";
  spack install --add kokkos@master "${compiler}" +shared \
    cxxstd="${cxxstd}" +aggressive_vectorization +examples +hwloc \
    +memkind +numactl +tuning +serial +openmp \
    +wrapper +cuda cuda_arch="${cuda_arch}" +cuda_lambda;
  # spack install --add kokkos@master "${compiler}" +shared \
  #   cxxstd="${cxxstd}" +aggressive_vectorization +examples +hwloc \
  #   +memkind +numactl +tuning +serial +pic +hpx +hpx_async_dispatch \
  #   +wrapper +cuda cuda_arch="${cuda_arch}" +cuda_lambda;
  spack install --add kokkos-kernels@master "${compiler}" +shared \
    +blas +lapack +superlu +cublas +cusparse \
    scalars=complex_double,complex_float,double,float \
    +serial +openmp \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add petsc@main "${compiler}" +shared \
    +hpddm +hwloc +memkind +mumps +hypre +kokkos +strumpack +random123 \
    +openmp +valgrind \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add ginkgo@develop "${compiler}" +shared \
    +full_optimizations +hwloc +mpi +openmp \
    +cuda cuda_arch="${cuda_arch}";
  spack install --add sundials "${compiler}" +shared \
    cxxstd="${cxxstd}" +openmp +hypre +petsc +superlu-dist \
    logging-level=5 +logging-mpi \
    +cuda cuda_arch="${cuda_arch}"; #+ginkgo +kokkos +kokkos-kernels
  # spack install --add py-pip "${compiler}";
  # spack install --add py-setuptools "${compiler}";
  # spack install --add py-wheel "${compiler}";
  # spack install --add py-pybind11 "${compiler}";
  # spack install --add py-pyyaml "${compiler}";
  # spack install --add py-numpy "${compiler}";
  # spack install --add py-scipy "${compiler}";
  # spack install --add py-matplotlib "${compiler}";
  # spack install --add py-tables "${compiler}" +lzo +zlib +bzip2;
  # spack install --add py-pandas "${compiler}";
  # spack install --add meshtool@master "${compiler}";
  # spack install --add py-carputils@master "${compiler}";
  # spack install --add fftw "${compiler}" +openmp;
  # spack install --add opencarp@master "${compiler}" \
  #   +meshtool +carputils;
  return ${?};
}

openCARP_spack "${@}";
