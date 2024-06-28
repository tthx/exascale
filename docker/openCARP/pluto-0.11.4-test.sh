#!/bin/bash
set -euo pipefail;

test_pluto() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  . "${script_dir}/runtime-env.sh" "${pluto_runtime}";
  local cc="/usr/bin/gcc";
  local cflags="-O3 -march=native -fopenmp";
  local cc="$(llvm-config --bindir)/clang";
  local cflags="-O3 -march=native -fopenmp -fopenmp-targets=nvptx64-nvidia-cuda";
  local libs="-lgomp -lm";
  local src="seq-dptr-mult.c";
  local src_file="${dev_home}/matrix/src/${src}";
  local dest_file="/tmp/${src}";
  local exec_file="/tmp/a.out";
  local res_file="/tmp/test-pluto-$(pluto -v|awk '/^PLUTO/{if($2!="version") print $2; else print $3;}')-$(date +%F\ %T).txt";
  local i;
  local n=10000;
  local m=10000;
  local p=10000;
  local opts=( "--tile --parallel" );
  opts+=( "--l2tile --tile --parallel" );
  opts+=( "--partlbtile --parallel" );
  opts+=( "--l2tile --partlbtile --parallel" );
  opts+=( "--lbtile --parallel" );
  opts+=( "--l2tile --lbtile --parallel" );
  opts+=( "--multipar --tile --parallel" );
  opts+=( "--multipar --l2tile --tile --parallel" );
  opts+=( "--multipar --partlbtile --parallel" );
  opts+=( "--multipar --l2tile --partlbtile --parallel" );
  opts+=( "--multipar --lbtile --parallel" );
  opts+=( "--multipar --l2tile --lbtile --parallel" );
  opts+=( "--innerpar --tile --parallel" );
  opts+=( "--innerpar --l2tile --tile --parallel" );
  opts+=( "--innerpar --partlbtile --parallel" );
  opts+=( "--innerpar --l2tile --partlbtile --parallel" );
  opts+=( "--innerpar --lbtile --parallel" );
  opts+=( "--innerpar --l2tile --lbtile --parallel" );
  for i in ${!opts[@]};
  do
    echo "Option to test: [${opts[${i}]}]" 1>>"${res_file}" 2>&1;
    polycc ${opts[${i}]} "${src_file}" -o "${dest_file}" 1>>/dev/null 2>&1;
    ${cc} ${cflags} "${dest_file}" ${libs} -o "${exec_file}" 1>>/dev/null 2>&1;
    ( time "${exec_file}" ${n} ${m} ${p} x ) 1>>"${res_file}" 2>&1;
    echo 1>>"${res_file}" 2>&1;
  done
  return ${?};
}

test_pluto;
