#!/bin/bash
set -euo pipefail;

build_musl() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  local prefix;
  local cc;
  if [ ! -d "${musl_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${musl_branch}" \
      "${musl_repo_url}" \
      "${musl_src_dir}";
  fi
  cd "${musl_src_dir}";
  git pull --recurse-submodules;
  cc="/usr/bin/gcc";
  prefix="${musl_prefix}/gcc-$(${cc} --version | awk '/^gcc/{print $4}')";
  rm -rf "${prefix}";
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  ./configure \
    --prefix="${prefix}" \
    --syslibdir="${prefix}/lib";
  make clean;
  make -j $(nproc);
  make install;
  llvm_runtime_env;
  cc="$(llvm-config --bindir)/clang";
  prefix="${musl_prefix}/llvm-$(llvm-config --version)";
  rm -rf "${prefix}";
  export CC="${cc}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  ./configure \
    --prefix="${prefix}" \
    --syslibdir="${prefix}/lib";
  make clean;
  make -j $(nproc);
  make install;
  return ${?};
}

build_musl;
