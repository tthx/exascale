#!/bin/bash
set -euo pipefail;

backup() {
  if [ -f "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h" ];
  then
    cp -f "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h" \
      "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h.orig";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc" ];
  then
    cp -f "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc" \
      "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc.orig";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h" ];
  then
    cp -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h.orig";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc" ];
  then
    cp -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc.orig";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h" ];
  then
    cp -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h.orig";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h" ];
  then
    cp -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h.orig";
  fi
  return 0;
}

restore() {
  if [ -f "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h.orig" ];
  then
    mv -f "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h.orig" \
      "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc.orig" ];
  then
    mv -f "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc.orig" \
      "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h.orig" ];
  then
    mv -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h.orig" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc.orig" ];
  then
    mv -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc.orig" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h.orig" ];
  then
    mv -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h.orig" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h";
  fi
  if [ -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h.orig" ];
  then
    mv -f "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h.orig" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h";
  fi
  return 0;
}

apply_patches() {
  local vect_type="${1}";
  local new_dir="${dev_home}/openCARP/${opencarp_branch}";
  if [ "${vect_type}" != "default" ];
  then
    cp -f "${new_dir}/numerics/petsc/petsc_utils.cc" \
      "${opencarp_src_dir}/numerics/petsc/petsc_utils.cc";
    cp -f "${new_dir}/numerics/petsc/SF_petsc_solver.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.h";
    cp -f "${new_dir}/numerics/petsc/SF_petsc_solver.cc" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_solver.cc";
    cp -f "${new_dir}/fem/slimfem/src/SF_abstract_vector.${vect_type}.h" \
      "${opencarp_src_dir}/fem/slimfem/src/SF_abstract_vector.h";
    cp -f "${new_dir}/numerics/petsc/SF_petsc_matrix.${vect_type}.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_matrix.h";
    cp -f "${new_dir}/numerics/petsc/SF_petsc_vector.${vect_type}.h" \
      "${opencarp_src_dir}/numerics/petsc/SF_petsc_vector.h";
  fi
  return 0;
}

build_openCARP() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
  else
    echo "Usage: ${BASH_SOURCE} [embedded] <cuda_arch> <${mpi_impl_list//\ /\|}> <${vect_type_list//\ /\|}> [gcc|llvm](default:llvm) [poly](default:OFF) [cxx_dialect](default:17) [openmp](default:OFF)";
    return 0;
  fi
  local cuda_arch="${1:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  local vect_type="${3:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  check_vect_type "${vect_type}";
  python_runtime_env;
  cuda_runtime_env;
  llvm_runtime_env;
  if [ -z "${embedded}" ];
  then
    hwloc_runtime_env;
    ucx_runtime_env;
    mpi_impl_runtime_env "${mpi_impl}";
    parmetis_runtime_env "${mpi_impl}";
    scotch_runtime_env "${mpi_impl}";
    superlu_dist_runtime_env "${mpi_impl}";
    kokkos_runtime_env;
    kokkos_kernels_runtime_env;
    hypre_runtime_env "${mpi_impl}";
  fi
  petsc_runtime_env "${embedded}" "${mpi_impl}";
  ginkgo_runtime_env "${embedded}" "${mpi_impl}";
  local type="${4:-${llvm_type}}";
  local poly="${5:-OFF}";
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxx_dialect="${6:-17}";
  local openmp="${7:-OFF}";
  local cxxflags="${common_cxxflags}";
  local cudac="$(which nvcc)";
  local cudaflags="";
  local ldflags="";
  local libs="";
  local llvm_lit="$(which lit)";
  local filecheck="$(which FileCheck)";
  if [ "${type}" == "${llvm_type}" ];
  then
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
    ldflags+=" -L$(llvm-config --libdir) -lmlir_cuda_runtime -lomp";
    type+="-${poly}-$(${cc} --version | awk '/^gcc/{print $4}')"
  fi
  if [ -n "$(lscpu|grep -i " avx512 ")" ];
  then
    mlir_num_elements="8";
    prefer_vector_width="512";
  elif [ -n "$(lscpu|grep -i " avx2 ")" ];
  then
    mlir_num_elements="4";
    prefer_vector_width="256";
  fi
  cflags+=" -mprefer-vector-width=${prefer_vector_width}";
  cxxflags+=" -mprefer-vector-width=${prefer_vector_width}";
  if [ -z "${embedded}" ];
  then
    cflags+=" -I${gklib_prefix}/include -I${metis_prefix}/include -I${parmetis_prefix}/${mpi_impl}/include";
    cxxflags+=" -I${gklib_prefix}/include -I${metis_prefix}/include -I${parmetis_prefix}/${mpi_impl}/include";
    libs+=" -L${gklib_prefix}/lib -lGKlib -L${metis_prefix}/lib -lmetis -I${parmetis_prefix}/${mpi_impl}/lib -lparmetis";
  fi
  if [ ! -d "${opencarp_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${opencarp_branch}" \
      "${opencarp_repo_url}" \
      "${opencarp_src_dir}";
  fi
  cd "${opencarp_src_dir}";
  git pull --recurse-submodules;
  pip install --upgrade --no-cache-dir -r \
    "${opencarp_src_dir}/external/carputils/requirements.py3.txt";
  pip install --upgrade --no-cache-dir \
    "${opencarp_src_dir}/external/carputils";
  restore;
  backup;
  apply_patches "${vect_type}";
  opencarp_prefix+="${embedded:+/embedded}/${mpi_impl}/${vect_type}";
  rm -rf "${opencarp_prefix}" "./build/${vect_type}";
  mkdir -p "./build/${vect_type}";
  cd "./build/${vect_type}";
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXX="${cxx}";
  export CXXFLAGS="${cxxflags}";
  export CUDAC="${cudac}"
  export CUDACXX="${cudac}";
  export CUDAFLAGS="${cudaflags}";
  export LDFLAGS="${ldflags}";
  export LIBS="${libs}";
  cmake -G Ninja ../.. \
    -DCMAKE_C_COMPILER_LAUNCHER="ccache" \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_CXX_STANDARD="${cxx_dialect}" \
    -DCMAKE_CUDA_COMPILER_LAUNCHER="ccache" \
    -DCMAKE_CUDA_COMPILER="${cudac}" \
    -DCMAKE_CUDA_ARCHITECTURES="${cuda_arch}" \
    -DCMAKE_CUDA_FLAGS="${cudaflags}" \
    -DCUDA_STANDARD="${cxx_dialect}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_INSTALL_PREFIX="${opencarp_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_LIT="${llvm_lit}" \
    -DFILECHECK="${filecheck}" \
    -DMLIR_VECTOR_LIBRARY="LIBMVEC-X86" \
    -DENABLE_MLIR_CODEGEN=ON \
    -DMLIR_CUDA_PTX_FEATURE=ptx"${cuda_arch}" \
    -DBUILD_IGBDFT=ON \
    -DDLOPEN=ON \
    -DBUILD_EXTERNAL=ON \
    -DENABLE_GINKGO=OFF \
    -DBUILD_TESTS=ON \
    -DUSE_OPENMP="${openmp}";
  ninja physics/limpet/ION_IF_datatypes.h;
  ninja -j $(nproc);
  ninja install;
  cp -f ./physics/limpet/Transforms/llvm/libInternalLinkagePass.so \
    ./physics/limpet/Transforms/mlir/lib/ExecutionEngine/libopencarp_cuda_runtime.so \
    "${opencarp_prefix}/lib/.";
  restore;
  return ${?};
}

build_openCARP "${@}";
