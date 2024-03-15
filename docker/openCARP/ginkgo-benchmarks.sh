#!/bin/bash

select_matrix() {
  local min="${1:-90000000}";
  local max="${2:-100000000}";
  local x;
  local i;
  for i in $(seq 1 $(ssget -n));
  do
    #x=$(ssget -p cols -i ${i});
    x=$(ssget -p nonzeros -i ${i});
    if [ ${x} -ge ${min} ] && [ ${x} -le ${max} ];
    then
      printf "%s " "${i}";
    fi
  done
  printf "\n";
}

ginkgo_benchmarks() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  local cols;
  local i;
  local ginkgo_branch="${1:-polyhedral}";
  local type="${2:-reference}"
  local src_dir;
  if [ "${ginkgo_branch}" != "polyhedral" ];
  then
    ginkgo_branch="develop";
  fi
  . "${script_dir}/build-env.sh";
  if [ "${ginkgo_branch}" == "polyhedral" ];
  then
    src_dir="${ginkgo_polyhedral_src_dir}";
  else
    src_dir="${ginkgo_src_dir}";
  fi
  export BENCHMARK="solver";
  export EXECUTOR="${type}";
  case "$(hostname)" in
    "gits-icube")
      SYSTEM_NAME="12th Gen Intel(R) Core(TM) i7-12700H";
      ;;
    *)
      SYSTEM_NAME="Intel(R) Core(TM) i7-6700K CPU @ 4.00GHz";
      ;;
  esac
  export SYSTEM_NAME+="/$(date +%F\ %T)";
  export FORMATS="csr";
  export SOLVERS="cg";
  export SOLVERS_MAX_ITERATIONS="10000";
  export SOLVERS_RHS="random";
  export SOLVERS_INITIAL_GUESS="random";
  export SOLVER_REPETITIONS="10";
  export DETAILED="1";
  export MATRIX_LIST_FILE="/tmp/Ginkgo-benchmarks-matrix.txt";
  rm -f "${MATRIX_LIST_FILE}";
  for i in 916; #1902
  do
    echo "${i}" >> "${MATRIX_LIST_FILE}";
  done
  export OMP_NUM_THREADS="$(nproc)";
  cd "${src_dir}/build/benchmark";
  . "./run_all_benchmarks.sh";
  cd -;
  return ${?};
}

ginkgo_benchmarks "${@}";
