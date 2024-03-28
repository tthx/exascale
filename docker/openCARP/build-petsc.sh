#!/bin/bash
set -euo pipefail;

build_petsc_embedded() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  cuda_runtime_env;
  local mpi_download="";
  local mpi_configure_args="";
  case "${mpi_impl}" in
    "openmpi")
      mpi_download="https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.2.tar.gz";
      mpi_configure_args="--with-cuda=\"${CUDA_HOME}\" --with-cuda-libdir=\"${CUDA_HOME}/lib64/stubs\" --with-pmix --with-prrte --with-treematch";
      ;;
    "mpich")
      mpi_download="https://www.mpich.org/static/downloads/4.2.0/mpich-4.2.0.tar.gz";
      mpi_configure_args="--with-cuda=\"${CUDA_HOME}\" --enable-fast=all,O3";
      ;;
    *)
      echo "${errmsg} \"${mpi_impl}\" is not a supported MPI implementation.";
      return 1;
      ;;
  esac
  local type="${3:-${gcc_type}}";
  local poly="${4:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${5:-17}";
  local openmp="${6:-OFF}";
  local cudac="$(which nvcc)";
  local cudaflags=""; #"-arch=sm_${cuda_arch}";
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
  if [ ! -d "${petsc_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${petsc_branch}" \
      "${petsc_repo_url}" \
      "${petsc_src_dir}";
  fi
  cd "${petsc_src_dir}";
  git pull --recurse-submodules;
  petsc_prefix+="/embedded/${mpi_impl}";
  rm -rf "${petsc_prefix}" \
    ./arch-linux-c-opt \
    ./configure.log \
    ./make.log \
    ./configure.log.bkp;
  unset PETSC_DIR PETSC_ARCH HWLOC_HIDE_ERRORS;
  local x;
  if [ "${openmp}" == "OFF" ];
  then
    x="";
  else
    x="--with-openmp";
  fi
  local hypre_configure_args="--with-print-errors --with-timing --with-cxxstandard=\"${cxx_dialect}\" --with-cuda --with-cuda-home=\"${CUDA_HOME}\" --with-gpu-arch=\"${cuda_arch}\" --enable-cusolver --enable-unified-memory --enable-device-memory-pool --enable-device-malloc-async --enable-gpu-aware-mpi ${x}";
  local superlu_dist_cmake_args="-DTPL_ENABLE_CUDALIB=ON -DTPL_ENABLE_INTERNAL_BLASLIB=OFF -DTPL_ENABLE_LAPACKLIB=ON";
  local kokkos_cmake_args="-DKokkos_ENABLE_SERIAL=ON -DKokkos_ENABLE_OPENMP=${openmp} -DKokkos_ENABLE_CUDA=ON -DKokkos_ENABLE_AGGRESSIVE_VECTORIZATION=ON -DKokkos_ENABLE_TUNING=ON -DKokkos_ENABLE_HWLOC=ON -DKokkos_ARCH_NATIVE=ON";
  local kokkos_kernels_cmake_args="-DKokkos_ENABLE_SERIAL=ON -DKokkos_ENABLE_OPENMP=${openmp} -DKokkos_ENABLE_CUDA=ON -DKokkosKernels_ENABLE_TPL_BLAS=ON";
  if [ "${openmp}" == "OFF" ];
  then
    x=0;
  else
    x=1;
  fi
  ./configure \
    CC="${cc}" \
    CFLAGS="${cflags}" \
    COPTFLAGS="${cflags}" \
    CXX="${cxx}" \
    CXXFLAGS="${cxxflags}" \
    CXXOPTFLAGS="${cxxflags}" \
    CUDAC="${cudac}" \
    CUDAFLAGS="${cudaflags}" \
    FC="${fortran}" \
    FFLAGS="${fcflags}" \
    FOPTFLAGS="${fcflags}" \
    LDFLAGS="${ldflags}" \
    --prefix="${petsc_prefix}" \
    --with-clean=1 \
    --with-strict-petscerrorcode=0 \
    --with-debugging=0 \
    --with-openmp=${x} \
    --with-threadsafety=${x} \
    --with-cuda=1 \
    --with-cuda-dir="${cuda_root}" \
    --with-cuda-arch="${cuda_arch}" \
    --with-cxx-dialect="${cxx_dialect}" \
    --with-cuda-dialect="${cxx_dialect}" \
    --download-"${mpi_impl}"-configure-arguments="${mpi_configure_args}" \
    --with-ptscotch=1 \
    --with-metis=1 \
    --with-parmetis=1 \
    --with-hwloc=1 \
    --download-hwloc-configure-arguments="--with-cuda=\"${CUDA_HOME}\"" \
    --with-hypre=1 \
    --download-hypre-configure-arguments="${hypre_configure_args}" \
    --with-superlu_dist=1 \
    --download-superlu_dist-cmake-arguments="${superlu_dist_cmake_args}" \
    --download-fblaslapack \
    --download-ptscotch \
    --download-metis \
    --download-parmetis \
    --download-"${mpi_impl}"="${mpi_download}" \
    --download-hwloc="https://download.open-mpi.org/release/hwloc/v2.9/hwloc-2.9.3.tar.gz" \
    --download-hypre="https://github.com/hypre-space/hypre/archive/refs/tags/${hypre_branch}.tar.gz" \
    --download-superlu_dist="https://github.com/xiaoyeli/superlu_dist/archive/refs/tags/${superlu_dist_branch}.tar.gz" \
    --with-kokkos=1 \
    --download-kokkos-cmake-arguments="${kokkos_cmake_args}" \
    --with-kokkos-kernels=1 \
    --download-kokkos-kernels-cmake-arguments="${kokkos_kernels_cmake_args}" \
    --download-kokkos="https://github.com/kokkos/kokkos/archive/refs/tags/${kokkos_branch}.tar.gz" \
    --download-kokkos-kernels="https://github.com/kokkos/kokkos-kernels/archive/refs/tags/${kokkos_kernels_branch}.tar.gz";
    # --download-"${mpi_impl}" \
    # --download-hwloc \
    # --download-hypre \
    # --download-superlu_dist \
    # --download-kokkos \
    # --download-kokkos-kernels;

  make -j $(nproc) PETSC_DIR="${PWD}" PETSC_ARCH="arch-linux-c-opt" all;
  make PETSC_DIR="${PWD}" PETSC_ARCH="arch-linux-c-opt" install;
  mpi_env_var;
  make PETSC_DIR="${petsc_prefix}" PETSC_ARCH="" check;
  make -j $(nproc) \
    PETSC_DIR="${PWD}" \
    PETSC_ARCH="arch-linux-c-opt" \
    allgtests-tap;
  return ${?};
}

unpatch() {
  if [ -f "${petsc_src_dir}/config/BuildSystem/config/packages/metis.py.orig" ];
  then
    mv -f "${petsc_src_dir}/config/BuildSystem/config/packages/metis.py.orig" \
      "${petsc_src_dir}/config/BuildSystem/config/packages/metis.py";
  fi
}

build_petsc() {
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
  parmetis_runtime_env "${mpi_impl}";
  scotch_runtime_env "${mpi_impl}";
  superlu_dist_runtime_env "${mpi_impl}";
  hypre_runtime_env "${mpi_impl}";
  kokkos_runtime_env;
  kokkos_kernels_runtime_env;
  local type="${3:-${gcc_type}}";
  local poly="${4:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cxx_dialect="${5:-17}";
  local openmp="${6:-OFF}";
  local cudac="$(which nvcc)";
  local cudaflags=""; #"-arch=sm_${cuda_arch}";
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
  if [ ! -d "${petsc_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${petsc_branch}" \
      "${petsc_repo_url}" \
      "${petsc_src_dir}";
  fi
  cd "${petsc_src_dir}";
  git pull --recurse-submodules;
  petsc_prefix+="/${mpi_impl}";
  rm -rf "${petsc_prefix}" \
    ./arch-linux-c-opt \
    ./configure.log \
    ./make.log \
    ./configure.log.bkp;
  unset PETSC_DIR PETSC_ARCH HWLOC_HIDE_ERRORS;
  unpatch;
  local patch_dir="${dev_home}/petsc/${petsc_branch}";
  patch -b "${petsc_src_dir}/config/BuildSystem/config/packages/metis.py" \
    "${patch_dir}/config/BuildSystem/config/packages/metis.py.patch";
  local x;
  [[ "${openmp}"=="OFF" ]] && x="0" || x="1";
  ./configure \
    CFLAGS="${cflags}" \
    COPTFLAGS="${cflags}" \
    CXXFLAGS="${cxxflags}" \
    CXXOPTFLAGS="${cxxflags}" \
    CUDAC="${cudac}" \
    CUDAFLAGS="${cudaflags}" \
    FFLAGS="${fcflags}" \
    FOPTFLAGS="${fcflags}" \
    LDFLAGS="${ldflags}" \
    LIBS="-L${llvm_prefix}/lib -lomp" \
    --prefix="${petsc_prefix}" \
    --with-clean=1 \
    --with-strict-petscerrorcode=0 \
    --with-debugging=0 \
    --with-openmp=${x} \
    --with-threadsafety=${x} \
    --with-cuda=1 \
    --with-cuda-dir="${cuda_root}" \
    --with-cuda-arch="${cuda_arch}" \
    --with-cxx-dialect="${cxx_dialect}" \
    --with-cuda-dialect="${cxx_dialect}" \
    --with-mpi=1 \
    --with-mpi-dir="${MPI_HOME}" \
    --download-fblaslapack \
    --with-ptscotch=1 \
    --download-ptscotch \
    --with-metis=1 \
    --with-metis-include="[${metis_prefix}/include,${gklib_prefix}/include]" \
    --with-metis-lib="[${metis_prefix}/lib/libmetis.so,${gklib_prefix}/lib/libGKlib.a]" \
    --with-parmetis=1 \
    --with-parmetis-dir="${parmetis_prefix}/${mpi_impl}" \
    --with-hwloc=1 \
    --with-hwloc-dir="${hwloc_prefix}" \
    --with-hypre=1 \
    --with-hypre-dir="${hypre_prefix}/${mpi_impl}" \
    --with-superlu_dist=1 \
    --with-superlu_dist-dir="${superlu_dist_prefix}/${mpi_impl}" \
    --with-kokkos=1 \
    --with-kokkos-dir="${kokkos_prefix}" \
    --with-kokkos-kernels=1 \
    --with-kokkos-kernels-dir="${kokkos_kernels_prefix}";
  unpatch;
  make -j $(nproc) PETSC_DIR="${PWD}" PETSC_ARCH="arch-linux-c-opt" all;
  make PETSC_DIR="${PWD}" PETSC_ARCH="arch-linux-c-opt" install;
  mpi_env_var;
  make PETSC_DIR="${petsc_prefix}" PETSC_ARCH="" check;
  make -j $(nproc) \
    PETSC_DIR="${PWD}" \
    PETSC_ARCH="arch-linux-c-opt" \
    allgtests-tap;
  return ${?};
}

if [ ${#} -gt 0 ];
then
  if [ "${1}" == "embedded" ];
  then
    shift;
    build_petsc_embedded "${@}";
  else
    build_petsc "${@}";
  fi
else
  . "$(dirname "$(readlink -f "${BASH_SOURCE}")")/build-env.sh";
  echo "Usage: ${BASH_SOURCE} [embedded] <cuda_arch> <${mpi_impl_list//\ /\|}> [gcc|llvm](default:gcc) [poly](default:OFF) [cxx_dialect](default:17) [openmp](default:OFF)";
  exit 0;
fi
