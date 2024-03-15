#!/bin/bash
set -euo pipefail;

build_polygeist() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${polygeist_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${polygeist_branch}" \
      "${polygeist_repo_url}" \
      "${polygeist_src_dir}";
  fi
  cd "${polygeist_src_dir}";
  git pull --recurse-submodules;
  rm -rf ./llvm-project/build;
  mkdir -p ./llvm-project/build;
  cd ./llvm-project/build;
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
    -DLLVM_ENABLE_PROJECTS="mlir;clang" \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_CCACHE_BUILD=OFF;
  ninja -j $(nproc);
  ninja -j $(nproc) \
    check-clang \
    check-mlir;
  cd "${polygeist_src_dir}";
  rm -rf "${polygeist_prefix}" ./build;
  mkdir -p ./build;
  cd ./build;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  cmake -G Ninja .. \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    -DCMAKE_C_FLAGS="${cflags}" \
    -DCMAKE_CXX_FLAGS="${cxxflags}" \
    -DCMAKE_EXE_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${ldflags}" \
    -DCMAKE_MODULE_LINKER_FLAGS="${ldflags}" \
    -DMLIR_DIR="${PWD}/../llvm-project/build/lib/cmake/mlir" \
    -DCLANG_DIR="${PWD}/../llvm-project/build/lib/cmake/clang" \
    -DCMAKE_INSTALL_PREFIX="${polygeist_prefix}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DLLVM_ENABLE_ASSERTIONS=ON;
  ninja -j $(nproc);
  ninja -j $(nproc) \
    check-polygeist-opt \
    check-cgeist;
  ninja install;
  return ${?};
}

build_polygeist;
