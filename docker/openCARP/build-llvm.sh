#!/bin/bash
set -euo pipefail;

unpatch() {
  if [ -f "${llvm_src_dir}/openmp/libomptarget/include/Debug.h.orig" ];
  then
    mv -f "${llvm_src_dir}/openmp/libomptarget/include/Debug.h.orig" \
      "${llvm_src_dir}/openmp/libomptarget/include/Debug.h";
  fi
}

# ERROR: llvm-15.x: openmp check failed
check_llvm_projects() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local llvm_version="${1:?"${errmsg} Missing LLVM version"}";
  local llvm_projects="${2:?"${errmsg} Missing LLVM projects"}";
  local i;
  if [ "${llvm_version}" -eq 15 ];
  then
    llvm_projects="${llvm_projects/openmp/}";
  fi
  for i in ${llvm_projects};
  do
    ninja -j $(nproc) check-${i};
  done
  return 0;
}

build_n() {
  local llvm_src_dir="${1:?"${errmsg} Missing LLVM source directory"}";
  local llvm_prefix="${2:?"${errmsg} Missing LLVM prefix directory"}";
  local llvm_version="${3:?"${errmsg} Missing LLVM version"}";
  local llvm_projects="${4:?"${errmsg} Missing LLVM projects"}";
  local n="${5:?"${errmsg} Missing number to build"}";
  local cc="${6:?"${errmsg} Missing cc"}";
  local cxx="${7:?"${errmsg} Missing cxx"}";
  local cudac="${8:?"${errmsg} Missing cudac"}";
  local cflags="${9:?"${errmsg} Missing cflags"}";
  local cxxflags="${10:?"${errmsg} Missing cxxflags"}";
  local cuda_arch="${11:?"${errmsg} Missing cuda architecture"}";
  local ldflags="${12}";
  local cudaflags="-arch=sm_${cuda_arch}";
  local i=0;
  while [ ${i} -lt ${n} ];
  do
    cd "${llvm_src_dir}";
    rm -rf "./build_${i}";
    mkdir -p "./build_${i}";
    cd "./build_${i}";
    if [ ${i} -gt 0 ];
    then
      cc="${llvm_src_dir}/build_$((i-1))/bin/clang";
      cxx="${llvm_src_dir}/build_$((i-1))/bin/clang++";
    fi
    export CC="${cc}";
    export CFLAGS="${cflags}";
    export CXX="${cxx}";
    export CXXFLAGS="${cxxflags}";
    export CUDAC="${cudac}"
    export CUDACXX="${cudac}";
    export CUDAFLAGS="${cudaflags}";
    export LDFLAGS="${ldflags}";
    cmake -G Ninja ../llvm \
      -DCMAKE_C_COMPILER="${cc}" \
      -DCMAKE_C_FLAGS="${cflags}" \
      -DCMAKE_CXX_COMPILER="${cxx}" \
      -DCMAKE_CXX_FLAGS="${cxxflags}" \
      -DCMAKE_CUDA_COMPILER="${cudac}" \
      -DCMAKE_CUDA_ARCHITECTURES="${cuda_arch}" \
      -DCMAKE_CUDA_FLAGS="${cudaflags}" \
      -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
      -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
      -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
      -DCMAKE_INSTALL_PREFIX="${llvm_prefix}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS="${llvm_projects//\ /;}" \
      -DLLVM_ENABLE_RUNTIMES="compiler-rt;libc;libcxx;libcxxabi;libunwind" \
      -DLLVM_TARGETS_TO_BUILD="host;NVPTX" \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
      -DMLIR_ENABLE_CUDA_RUNNER=ON \
      -DBUILD_SHARED_LIBS=ON \
      -DLLVM_CCACHE_BUILD=ON \
      -DLLVM_BUILD_EXAMPLES=OFF;
    ninja -j $(nproc);
    check_llvm_projects "${llvm_version}" "${llvm_projects}";
    i=$((i+1));
  done
  return 0;
}

build_llvm() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local llvm_version="${1:?"${errmsg} Missing LLVM version"}";
  local cuda_arch="${2:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local n="${3:-1}";
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  python_runtime_env;
  cuda_runtime_env;
  local cc="/usr/bin/gcc";
  local cflags="${common_cflags}";
  local cxx="/usr/bin/g++";
  local cxxflags="${common_cxxflags}";
  local cudac="$(which nvcc)";
  local ldflags="";
  local llvm_projects="clang mlir polly openmp";
  if [ ! -d "${llvm_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${llvm_branch}" \
      "${llvm_repo_url}" \
      "${llvm_src_dir}";
  fi
  cd "${llvm_src_dir}";
  git pull --recurse-submodules;
  pip install --upgrade --no-cache-dir -r \
    "${llvm_src_dir}/mlir/python/requirements.txt";
  pip install --upgrade --no-cache-dir \
    "${llvm_src_dir}/llvm/utils/lit";
  local patch_dir="${dev_home}/llvm/${llvm_branch}";
  unpatch;
  if [ "${llvm_version}" -eq 15 ];
  then
    patch -b "${llvm_src_dir}/openmp/libomptarget/include/Debug.h" \
      "${patch_dir}/openmp/libomptarget/include/Debug.h.patch";
  fi
  rm -rf "${llvm_prefix}";
  build_n \
    "${llvm_src_dir}" \
    "${llvm_prefix}" \
    "${llvm_version}" \
    "${llvm_projects}" \
    "${n}" \
    "${cc}" \
    "${cxx}" \
    "${cudac}" \
    "${cflags}" \
    "${cxxflags}" \
    "${cuda_arch}" \
    "${ldflags}";
  cd "${llvm_src_dir}/build_$((n-1))";
  ninja install;
  unpatch;
  cp -f ./bin/FileCheck "${llvm_prefix}/bin/.";
  return 0;
}

build_llvm "${@}";
