#!/bin/bash
set -euo pipefail;

build_clang() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
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
  rm -rf "${llvm_prefix}" ./build_1 ./build_2;
  mkdir -p ./build_1;
  cd ./build_1;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja ../llvm \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;openmp" \
    -DLLVM_TARGETS_TO_BUILD="host;NVPTX" \
    -DCLANG_OPENMP_NVPTX_DEFAULT_ARCH="sm_61" \
    -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES="61" \
    -DBUILD_SHARED_LIBS=ON \
    -DLLVM_CCACHE_BUILD=OFF \
    -DLLVM_BUILD_EXAMPLES=OFF;
  ninja -j $(nproc);
  ninja -j $(nproc) \
    check-clang \
    check-openmp;
  cd "${llvm_src_dir}";
  mkdir -p ./build_2;
  cd ./build_2;
  export CC="${llvm_src_dir}/build_1/bin/clang";
  export CXX="${llvm_src_dir}/build_1/bin/clang++";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja ../llvm \
    -DCMAKE_C_COMPILER="${llvm_src_dir}/build_1/bin/clang" \
    -DCMAKE_CXX_COMPILER="${llvm_src_dir}/build_1/bin/clang++" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${llvm_prefix}" \
    -DLLVM_ENABLE_PROJECTS="clang;openmp" \
    -DLLVM_TARGETS_TO_BUILD="host;NVPTX" \
    -DCLANG_OPENMP_NVPTX_DEFAULT_ARCH="sm_61" \
    -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES="61" \
    -DBUILD_SHARED_LIBS=ON \
    -DLLVM_CCACHE_BUILD=OFF \
    -DLLVM_BUILD_EXAMPLES=OFF;
  ninja -j $(nproc);
  ninja -j $(nproc) \
    check-clang \
    check-openmp;
  ninja install;
  cp -f ./bin/FileCheck "${llvm_prefix}/bin/.";
  return ${?};
}

build_clang;

