#!/bin/bash
set -euo pipefail;

check_flavor() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local flavor="${1:?"${errmsg} Missing flavor"}";
  local i;
  local err=1;
  for i in ${flavor_list};
  do
    if [ "${flavor}" == "${i}" ];
    then
      err=0;
      break;
    fi
  done
  if [ ${err} -eq 1 ];
  then
    echoerr "${errmsg} Unknown flavor \"${flavor}\".";
  fi
  return ${err};
}

openCARP_example() {
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
    echo "Usage: ${BASH_SOURCE} [embedded] <petsc|ginkgo> <${mpi_impl_list//\ /\|}> <${vect_type_list//\ /\|}> [PETSc options]";
    return 0;
  fi
  local flavor="${1:?"${errmsg} Missing flavor"}";
  check_flavor "${flavor}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  local vect_type="${3:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  check_vect_type "${vect_type}";
  local petsc_options="${4:-""}";
  python_runtime_env;
  cuda_runtime_env;
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
  openCARP_runtime_env "${embedded}" "${mpi_impl}" "${vect_type}";
  carputil_runtime_env "${embedded}" "${mpi_impl}" "${vect_type}";
  ln -sf "${carputils_settings_file_dir}/settings-${flavor}.yaml" \
    "${carputils_settings_file_dir}/settings.yaml";
  cd "${opencarp_src_dir}/external/experiments/tutorials/01_EP_single_cell/01_basic_bench";
  ./run.py --EP tenTusscherPanfilov --duration 20000 --bcl 500 --ID exp04 \
    --EP-par "GNa-62%,GCaL-69%,GKr-70%,GK1-80%" \
    --overwrite-behaviour overwrite \
    ${petsc_options:+--CARP-opts "+ -use_gpu_aware_mpi 1 ${petsc_options}"};
  return ${?};
}

openCARP_example "${@}";
