#!/bin/bash
set -euo pipefail;

test_pluto() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  local pluto_branch="master";
  . "${script_dir}/build-env.sh";
  . "${script_dir}/runtime-env.sh" "${pluto_runtime}";
  local cc="/usr/bin/gcc";
  local cflags="-O3 -march=native -fopenmp";
  local libs="-lgomp -lm";
  local src="seq-dptr-mult.c";
  local src_file="${dev_home}/matrix/src/${src}";
  local dest_file="/tmp/${src}";
  local exec_file="/tmp/a.out";
  local i;
  local n=10000;
  local m=10000;
  local p=10000;
  local opts=( "--tile --parallel" );
  opts+=( "--second-level-tile --tile --parallel" );
  opts+=( "--full-diamond-tile --second-level-tile --tile --parallel" );
  opts+=( "--multipar --full-diamond-tile --second-level-tile --tile --parallel" );
  opts+=( "--innerpar --multipar --full-diamond-tile --second-level-tile --tile --parallel" );
  echo "Without pet:";
  for i in ${!opts[@]};
  do
    echo "Option to test: [${opts[${i}]}]";
    polycc ${opts[${i}]} "${src_file}" -o "${dest_file}";
    ${cc} ${cflags} "${dest_file}" ${libs} -o "${exec_file}";
    time "${exec_file}" ${n} ${m} ${p} x;
    echo;
  done
  echo "#########";
  echo "With pet:";
  for i in ${!opts[@]};
  do
    echo "Option to test: [--pet ${opts[${i}]}]";
    polycc --pet ${opts[${i}]} "${src_file}" -o "${dest_file}";
    ${cc} ${cflags} "${dest_file}" ${libs} -o "${exec_file}";
    time "${exec_file}" ${n} ${m} ${p} x;
    echo;
  done
  return ${?};
}

test_pluto;
