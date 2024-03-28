#!/bin/bash
set -euo pipefail;

openCARP_setup() {
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
    echo "Usage: ${BASH_SOURCE} [embedded] <llvm_version> <cuda_arch> <${mpi_impl_list//\ /\|}> <${vect_type_list//\ /\|}>";
    return 0;
  fi
  local llvm_version="${1:?"${errmsg} Missing LLVM version"}";
  local cuda_arch="${2:?"${errmsg} Missing CUDA arch (e.g. 61, 86, 75)"}";
  local mpi_impl="${3:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  local vect_type="${4:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  check_vect_type "${vect_type}";
  ln -sf "${script_dir}/.bash_aliases" ~/.;
  "${script_dir}/openCARP-apt.sh";
  "${script_dir}/build-llvm.sh" \
    "${llvm_version}" \
    "${cuda_arch}";
  if [ -z "${embedded}" ];
  then
    "${script_dir}/build-ucx.sh" "${cuda_arch}";
    "${script_dir}/build-hwloc.sh" "${cuda_arch}";
    "${script_dir}/build-${mpi_impl}.sh" "${cuda_arch}";
    "${script_dir}/build-parmetis.sh" "${mpi_impl}";
    "${script_dir}/build-scotch.sh" "${mpi_impl}";
    "${script_dir}/build-superlu_dist.sh" \
      "${cuda_arch}" \
      "${mpi_impl}";
    "${script_dir}/build-kokkos.sh" "${cuda_arch}";
    "${script_dir}/build-kokkos-kernels.sh" "${cuda_arch}";
    "${script_dir}/build-hypre.sh" "${cuda_arch}" \
    "${mpi_impl}";
  fi
  "${script_dir}/build-petsc.sh" \
    "${embedded}" \
    "${cuda_arch}" \
    "${mpi_impl}";
  "${script_dir}/build-ginkgo.sh" \
    "${embedded}" \
    "${cuda_arch}" \
    "${mpi_impl}";
  "${script_dir}/build-openCARP.sh" \
    "${embedded}" \
    "${cuda_arch}" \
    "${mpi_impl} \
    ${vect_type}";
  "${script_dir}/build-autotester.sh";
  return ${?};
}

openCARP_setup "${@}";
