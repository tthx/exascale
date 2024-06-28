#!/bin/bash
set -euo pipefail;

restore() {
  if [ -f "${pluto_src_dir}/pet/scan.h.orig" ];
  then
    mv -f "${pluto_src_dir}/pet/scan.h.orig" \
      "${pluto_src_dir}/pet/scan.h";
  fi
  if [ -f "${pluto_src_dir}/pet/scop_plus.h.orig" ];
  then
    mv -f "${pluto_src_dir}/pet/scop_plus.h.orig" \
      "${pluto_src_dir}/pet/scop_plus.h";
  fi
  if [ -f "${pluto_src_dir}/cloog-isl/Makefile.orig" ];
  then
    mv "${pluto_src_dir}/cloog-isl/Makefile.orig" \
      "${pluto_src_dir}/cloog-isl/Makefile";
  fi
  return 0;
}

apply_patches() {
  patch -b "${pluto_src_dir}/pet/scan.h" \
    "${dev_home}/pluto/pet/scan.h.patch";
  patch -b "${pluto_src_dir}/pet/scop_plus.h" \
    "${dev_home}/pluto/pet/scop_plus.h.patch";
  patch -b "${pluto_src_dir}/cloog-isl/Makefile" \
    "${dev_home}/pluto/cloog-isl/Makefile.patch";
  return 0;
}

build_pluto() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/runtime-env.sh";
  python_runtime_env;
  cuda_runtime_env;
  llvm_runtime_env;
  local cc="/usr/bin/gcc";
  local cxx="/usr/bin/g++";
  local cflags="${common_cflags}";
  local cxxflags="${common_cxxflags}";
  local ldflags="";
  if [ ! -d "${pluto_src_dir}" ];
  then
    git clone \
      --depth=1 \
      --recursive \
      -b "${pluto_branch}" \
      "${pluto_repo_url}" \
      "${pluto_src_dir}";
  fi
  cd "${pluto_src_dir}";
  git pull --recurse-submodules;
  rm -rf "${pluto_prefix}";
  ./autogen.sh;
  export CC="${cc}";
  export CXX="${cxx}";
  export CFLAGS="${cflags}";
  export CXXFLAGS="${cxxflags}";
  export LDFLAGS="${ldflags}";
  export LIBS="$(llvm-config --ldflags) -lclangASTMatchers -lclangSupport -lclangBasic";
  ./configure \
    --prefix="${pluto_prefix}" \
    --with-clang-prefix="$(llvm-config --prefix)" \
    --enable-glpk;
  if [ "${pluto_branch}" != "0.12.0" ] && [ "${pluto_branch}" != "master" ];
  then
    restore;
    make clean;
    apply_patches;
    make -j $(nproc) all;
    make test;
    make install;
    restore;
    cp -f "${dev_home}/pluto/inscop" \
      "${pluto_prefix}/bin/.";
    cp -f "${dev_home}/pluto/polycc" \
      "${pluto_prefix}/bin/.";
  else
    make -j $(nproc);
    make check-pluto;
  fi
  return ${?};
}

build_pluto;
