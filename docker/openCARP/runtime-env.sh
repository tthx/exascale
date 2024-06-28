#!/bin/bash

echoerr() { printf "%s\n" "${@}" >&2; }

check_vect_type() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local vect_type="${1:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  local i;
  local r=0;
  for i in ${vect_type_list};
  do
    if [ "${i}" == "${vect_type}" ];
    then
      r=1;
      break;
    fi
  done
  if [ ${r} -eq 0 ];
  then
    echo "${errmsg} \"${vect_type}\" is not a supported vector/matrix.";
    echo "${errmsg} Only [${vect_type_list//\ /,\ }] are available."
    return 1;
  fi
  return 0;
}

locate_script() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local script_path="${1:?"${errmsg} Missing path"}";
  while [ -L "${script_path}" ];
  do
    script_dir="$(cd -P "$(dirname "${script_path}")" >/dev/null 2>&1 && pwd)";
    script_path="$(readlink "${script_path}")";
    [[ ${script_path} != /* ]] && script_path="${script_dir}/${script_path}";
  done
  script_path="$(readlink -f "${script_path}")";
  script_dir="$(cd -P "$(dirname -- "${script_path}")" >/dev/null 2>&1 && pwd)";
  printf "%s" "${script_dir}";
  return ${?};
}

strip_script() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local script_path="${1:?"${errmsg} Missing path"}";
  for i in "${1}/bin/"*;
  do
    if [ -n "$(file "${i}" | grep "not stripped" -)" ]
    then
      strip -s "${i}";
    fi
  done
  return ${?};
}

encode_type() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local petsc_type="${1:?"${errmsg} Missing PETSc compiler"}";
  local ginkgo_type="${2:?"${errmsg} Missing Ginkgo compiler"}";
  local openCARP_type="${3:?"${errmsg} Missing openCARP compiler"}";
  local type="";
  local i;
  for i in "${petsc_type}" "${ginkgo_type}" "${openCARP_type}";
  do
    case "${i}" in
      "${gcc_type}")
        type+="g";
        ;;
      "${llvm_type}")
        type+="l";
        ;;
      *)
        echoerr "${errmsg} Unknown type \"${i}\".";
        return 1;
        ;;
    esac
  done
  printf "%s\n" "${type}";
  return 0;
}

decode_type() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local type="${1:?"${errmsg} Missing type"}";
  local petsc_type="";
  local ginkgo_type="";
  local openCARP_type="";
  case "${type}" in
    g??)
      petsc_type="${gcc_type}";
      ;;
    l??)
      petsc_type="${llvm_type}";
      ;;
    *)
      echoerr "${errmsg} Unknown type \"${type}\" for PETSc.";
      return 1;
      ;;
  esac
  case "${type}" in
    ?g?)
      ginkgo_type="${gcc_type}";
      ;;
    ?l?)
      ginkgo_type="${llvm_type}";
      ;;
    *)
      echoerr "${errmsg} Unknown type \"${type}\" for Ginkgo.";
      return 1;
      ;;
  esac
  case "${type}" in
    ??g)
      openCARP_type="${gcc_type}";
      ;;
    ??l)
      openCARP_type="${llvm_type}";
      ;;
    *)
      echoerr "${errmsg} Unknown type \"${type}\" for openCARP.";
      return 1;
      ;;
  esac
  printf "%s %s %s\n" \
    "${petsc_type}" \
    "${ginkgo_type}" \
    "${openCARP_type}";
  return 0;
}

python_runtime_env() {
  local i;
  if [ -d "${HOME}/.venv/${env_name}" ];
  then
    . "${HOME}/.venv/${env_name}/bin/activate";
    for i in "${HOME}/.venv/${env_name}/lib/python${python_version}/site-packages/pybind11/share/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
    if [ -d "${opencarp_src_dir}/external/experiments/regression" ];
    then
      export PYTHONPATH="${opencarp_src_dir}/external/experiments/regression${PYTHONPATH:+:${PYTHONPATH}}";
    fi
  fi
  return 0;
}

nvhpc_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local nvhpc_dir="";
  if [ -d "${nvhpc_root}" ];
  then
    NVARCH="$(uname -s)_$(uname -m)";
    NVCOMPILERS="${nvhpc_root}";
    nvhpc_dir="${NVCOMPILERS}/${NVARCH}/${nvhpc_version}";
    MANPATH="${nvhpc_dir}/compilers/man${MANPATH:+:${MANPATH}}";
    PATH="${nvhpc_dir}/compilers/bin${PATH:+:${PATH}}";
    LD_LIBRARY_PATH="${nvhpc_dir}/compilers/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    CMAKE_PREFIX_PATH="${nvhpc_dir}/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    export NVARCH NVCOMPILERS MANPATH PATH LD_LIBRARY_PATH CMAKE_PREFIX_PATH;
  elif [ -z "$(which nvc++)" ];
  then
    echoerr "${errmsg} NVIDIA HPC SDK found.";
    return 1;
  fi
  return 0;
}

cuda_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local i;
  if [ -d "${cuda_root}" ];
  then
    export CUDA_HOME="${cuda_root}";
    export PATH="${CUDA_HOME}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${CUDA_HOME}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${CUDA_HOME}/lib64/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  elif [ -z "$(which nvcc)" ];
  then
    echoerr "${errmsg} No Cuda found.";
    return 1;
  fi
  return 0;
}

hwloc_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${hwloc_prefix}";
  if [ -d "${prefix}" ];
  then
    export HWLOC_DIR="${prefix}";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
  else
    echoerr "${errmsg} No hwloc found.";
    return 1;
  fi
  return 0;
}

openpmix_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${openpmix_prefix}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
  else
    echoerr "${errmsg} No openpmix found.";
    return 1;
  fi
  return 0;
}

prrte_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${prrte_prefix}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
  else
    echoerr "${errmsg} No prrte found.";
    return 1;
  fi
  return 0;
}

libfabric_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${libfabric_prefix}";
  if [ -d "${prefix}" ];
  then
    export LIBFABRIC_ROOT="${prefix}";
    export LIBFABRIC_INCLUDE_DIR="${prefix}/include";
    export LIBFABRIC_LIBRARY="${prefix}/lib";
    export PATH="${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
  else
    echoerr "${errmsg} No libfabric found.";
    return 1;
  fi
  return 0;
}

lci_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${lci_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No lci found.";
    return 1;
  fi
  return 0;
}

ucx_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${ucx_prefix}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No ucx found.";
    return 1;
  fi
  return 0;
}

check_mpi_impl() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local i;
  local r=0;
  for i in ${mpi_impl_list};
  do
    if [ "${i}" == "${mpi_impl}" ];
    then
      r=1;
      break;
    fi
  done
  if [ ${r} -eq 0 ];
  then
    echo "${errmsg} \"${mpi_impl}\" is not a supported MPI implementation.";
    echo "${errmsg} Only [${mpi_impl_list//\ /,\ }] are available."
    return 1;
  fi
  return 0;
}

mpi_env_var() {
  export HWLOC_HIDE_ERRORS="2";
  export OMPI_ALLOW_RUN_AS_ROOT="1";
  export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM="1";
  export OMP_PROC_BIND="spread";
  export OMP_PLACES="threads";
  export OMP_NUM_THREADS="1";
}

mpi_impl_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  case "${mpi_impl}" in
    "openmpi")
      openmpi_runtime_env;
      ;;
    "mpich")
      mpich_runtime_env;
      ;;
    *)
      echo "${errmsg} \"${mpi_impl}\" is not a supported MPI implementation.";
      echo "${errmsg} Only [${mpi_impl_list//\ /,\ }] are available."
      return 1;
      ;;
  esac
  return 0;
}

mpich_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${mpich_prefix}";
  if [ -d "${prefix}" ];
  then
    export MPI_HOME="${prefix}";
    export PKG_MPI_NAME="mpich";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
    mpi_env_var;
  else
    echoerr "${errmsg} No mpich found.";
    return 1;
  fi
  return 0;
}

openmpi_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${openmpi_prefix}";
  if [ -d "${prefix}" ];
  then
    export MPI_HOME="${prefix}";
    export PKG_MPI_NAME="ompi";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
    mpi_env_var;
  else
    echoerr "${errmsg} No openmpi found.";
    return 1;
  fi
  return 0;
}

boost_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${boost_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export BOOST_ROOT="${prefix}";
    export BOOST_INCLUDEDIR="${prefix}/include";
    export BOOST_LIBRARYDIR="${prefix}/lib";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export CMAKE_PREFIX_PATH="${prefix}/lib/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
  else
    echoerr "${errmsg} No boost found.";
    return 1;
  fi
  return 0;
}

parmetis_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${gklib_prefix}";
  if [ -d "${prefix}" ];
  then
    export GKLIB_DIR="${prefix}";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No gklib found.";
    return 1;
  fi
  prefix="${metis_prefix}";
  if [ -d "${prefix}" ];
  then
    export METIS_DIR="${prefix}";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No metis found.";
    return 1;
  fi
  prefix="${parmetis_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PARMETIS_DIR="${prefix}";
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No parmetis found.";
    return 1;
  fi
  return 0;
}

superlu_dist_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${superlu_dist_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
  else
    echoerr "${errmsg} No superlu_dist found.";
    return 1;
  fi
  return 0;
}

scotch_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${scotch_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No scotch found.";
    return 1;
  fi
  return 0;
}

hypre_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${hypre_prefix}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/sbin:${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No hypre found.";
    return 1;
  fi
  return 0;
}

hpx_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${hpx_prefix}";
  if [ -d "${prefix}" ];
  then
    export HPX_DIR="${prefix}";
    export PATH="${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No HPx found.";
    return 1;
  fi
  return 0;
}

kokkos_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${kokkos_prefix}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No Kokkos found.";
    return 1;
  fi
  return 0;
}

kokkos_kernels_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="${kokkos_kernels_prefix}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No Kokkos Kernels found.";
    return 1;
  fi
  return 0;
}

petsc_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
  fi
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${petsc_prefix}${embedded:+/embedded}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export PETSC_DIR="${prefix}";
    export PETSC_ARCH="";
    export PATH="${PETSC_DIR}${PETSC_ARCH:+/${PETSC_ARCH}}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${PETSC_DIR}${PETSC_ARCH:+/${PETSC_ARCH}}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    export PKG_CONFIG_PATH="${PETSC_DIR}${PETSC_ARCH:+/${PETSC_ARCH}}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}";
    # https://petsc.org/release/faq/#what-does-the-message-hwloc-linux-ignoring-pci-device-with-non-16bit-domain-
    mpi_env_var;
  else
    echoerr "${errmsg} No PETSc found.";
    return 1;
  fi
  return 0;
}

ginkgo_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
  fi
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local prefix="${ginkgo_prefix}${embedded:+/embedded}/${mpi_impl}";
  if [ -d "${prefix}" ];
  then
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No Ginkgo found.";
    return 1;
  fi
  return 0;
}

openCARP_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
  fi
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local vect_type="${2:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  local prefix="${opencarp_prefix}${embedded:+/embedded}/${mpi_impl}/${vect_type}";
  if [ -d "${prefix}" ];
  then
    export PATH="${prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
    for i in "${prefix}/lib/cmake/"*;
    do
      CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
    done
    export CMAKE_PREFIX_PATH;
  else
    echoerr "${errmsg} No openCARP found.";
    return 1;
  fi
  return 0;
}

carputil_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
  fi
  local mpi_impl="${1:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  local vect_type="${2:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  local prefix="${opencarp_prefix}${embedded:+/embedded}/${mpi_impl}/${vect_type}";
  rm -f "${carputils_settings_file_dir}/settings.yaml" && \
  python "${opencarp_src_dir}/external/carputils/bin/cusettings" \
    "${carputils_settings_file_dir}/settings.yaml" \
    --software-root "${prefix}/bin" \
    --regression-ref "${opencarp_src_dir}/external/experiments/regression-references" \
    --opencarp-src "${opencarp_src_dir}" && \
  sed \
    -e 's/\(DIRECT_SOLVER:[[:space:]]*\)'"MUMPS"'\(.*\)/\1'"SUPERLU_DIST"'\2/g' \
    -e 's/\(PURK_SOLVER:[[:space:]]*\)'"GMRES"'\(.*\)/\1'"SUPERLU_DIST"'\2/g' \
    "${carputils_settings_file_dir}/settings.yaml" | \
    tee "${carputils_settings_file_dir}/settings-${petsc_flavor}.yaml" > /dev/null && \
  sed \
    -e 's/\(FLAVOR:[[:space:]]*\)'"${petsc_flavor}"'\(.*\)/\1'"${direct_flavor}"'\2/g' \
    "${carputils_settings_file_dir}/settings-${petsc_flavor}.yaml" | \
    tee "${carputils_settings_file_dir}/settings-${direct_flavor}.yaml" > /dev/null && \
  sed \
    -e 's/\(FLAVOR:[[:space:]]*\)'"${petsc_flavor}"'\(.*\)/\1'"${pt_flavor}"'\2/g' \
    "${carputils_settings_file_dir}/settings-${petsc_flavor}.yaml" | \
    tee "${carputils_settings_file_dir}/settings-${pt_flavor}.yaml" > /dev/null && \
  sed \
    -e 's/\(FLAVOR:[[:space:]]*\)'"${petsc_flavor}"'\(.*\)/\1'"${ginkgo_flavor}"'\2/g' \
    "${carputils_settings_file_dir}/settings-${petsc_flavor}.yaml" | \
    tee "${carputils_settings_file_dir}/settings-${ginkgo_flavor}.yaml" > /dev/null && \
  rm -f "${carputils_settings_file_dir}/settings.yaml";
  return ${?};
}

llvm_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local prefix="";
  local i;
  if [ -f "${llvm_prefix}/bin/llvm-config" ];
  then
    prefix="$(${llvm_prefix}/bin/llvm-config --prefix)";
  elif [ -n "$(which llvm-config-${llvm_version})" ];
  then
    prefix="$(llvm-config-${llvm_version} --prefix)";
  else
    echoerr "${errmsg} No LLVM found.";
    return 1;
  fi
  export PATH="$(${prefix}/bin/llvm-config --bindir)${PATH:+:${PATH}}";
  export LD_LIBRARY_PATH="$(${prefix}/bin/llvm-config --libdir)${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  for i in "$(${prefix}/bin/llvm-config --libdir)/cmake/"*;
  do
    CMAKE_PREFIX_PATH="${i}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}";
  done
  export CMAKE_PREFIX_PATH;
  for i in "$(${prefix}/bin/llvm-config --prefix)/python_packages/"*;
  do
    PYTHONPATH="${i}${PYTHONPATH:+:${PYTHONPATH}}";
  done
  export PYTHONPATH;
  return 0;
}

pluto_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  if [ -f "${pluto_prefix}/bin/pluto" ];
  then
    export PATH="${pluto_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${pluto_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No Pluto found.";
    return 1;
  fi
  return 0;
}

poly_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  if [ -f "${clan_prefix}/bin/clan" ];
  then
    export PATH="${clan_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${clan_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No clan found.";
    return 1;
  fi
  if [ -f "${candl_prefix}/bin/candl" ];
  then
    export PATH="${candl_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${candl_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No candl found.";
    return 1;
  fi
  if [ -f "${cloog_prefix}/bin/cloog" ];
  then
    export PATH="${cloog_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${cloog_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No cloog found.";
    return 1;
  fi
  if [ -f "${clay_prefix}/bin/clay" ];
  then
    export PATH="${clay_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${clay_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No clay found.";
    return 1;
  fi
  if [ -f "${pet_prefix}/bin/pet" ];
  then
    export PATH="${pet_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${pet_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No pet found.";
    return 1;
  fi
  if [ -d "${piplib_prefix}" ];
  then
    export PATH="${piplib_prefix}/bin${PATH:+:${PATH}}";
    export LD_LIBRARY_PATH="${piplib_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No piplib found.";
    return 1;
  fi
  if [ -d "${osl_prefix}" ];
  then
    export LD_LIBRARY_PATH="${osl_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No osl found.";
    return 1;
  fi
  if [ -d "${isl_prefix}" ];
  then
    export LD_LIBRARY_PATH="${isl_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}";
  else
    echoerr "${errmsg} No isl found.";
    return 1;
  fi
  return 0;
}

spack_runtime_env() {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local mpi_impl="";
  if [ ${#} -gt 0 ];
  then
    check_mpi_impl "${1}";
    if [ ${?} -eq 1 ];
    then
      return 1;
    fi
    mpi_impl="${1}";
  else
    echo "Usage: ${FUNCNAME[0]} <${mpi_impl_list//\ /\|}>";
    return 0;
  fi
  if [ -f "${spack_src_dir}/share/spack/setup-env.sh" ];
  then
    . "${spack_src_dir}/share/spack/setup-env.sh";
    if [ -n "${mpi_impl}" ];
    then
      if [ -n "$(spack env list|grep "${env_name}-${mpi_impl}")" ];
      then
        spack env activate -p "${env_name}-${mpi_impl}";
      else
        echo "${errmsg} No Spack's environment \"${env_name}-${mpi_impl}\" found.";
        return 1;
      fi
    fi
  else
    echo "${errmsg} No Spack found.";
    return 1;
  fi
  return 0;
}

runtime_env() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  . "${script_dir}/build-env.sh";
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local embedded="";
  if [ ${#} -gt 0 ];
  then
    if [ "${1}" == "embedded" ];
    then
      embedded="${1}";
      shift;
    fi
    if [ "${1}" == "help" ];
    then
      echo "Usage: ${BASH_SOURCE} [${python_runtime}|${cuda_runtime}|${nvhpc_runtime}|${llvm_runtime}|${spack_runtime} [${mpi_impl_list//\ /\|}]|[embedded] ${openCARP_runtime} <${mpi_impl_list//\ /\|}> <${vect_type_list//\ /\|}>|${pluto_runtime}|${poly_runtime}|help]";
      return 0;
    fi
  fi
  local torun="${1:-"no"}";
  local mpi_impl="${2:-"no"}";
  local vect_type="${3:-"no"}";
  if [ -d "${cmake_prefix}" ];
  then
    PATH="${cmake_prefix}/bin${PATH:+:${PATH}}";
  fi
  case "${torun}" in
    "${python_runtime}")
      python_runtime_env;
      ;;
    "${nvhpc_runtime}")
      nvhpc_runtime_env;
      ;;
    "${cuda_runtime}")
      cuda_runtime_env;
      ;;
    "${llvm_runtime}")
      python_runtime_env && \
      cuda_runtime_env && \
      llvm_runtime_env;
      ;;
    "${openCARP_runtime}")
      check_mpi_impl "${mpi_impl}" && \
      check_vect_type "${vect_type}" && \
      python_runtime_env && \
      cuda_runtime_env && \
      llvm_runtime_env;
      if [ -z "${embedded}" ];
      then
        hwloc_runtime_env && \
        ucx_runtime_env && \
        mpi_impl_runtime_env "${mpi_impl}" && \
        parmetis_runtime_env "${mpi_impl}" && \
        scotch_runtime_env "${mpi_impl}" && \
        superlu_dist_runtime_env "${mpi_impl}" && \
        kokkos_runtime_env && \
        kokkos_kernels_runtime_env && \
        hypre_runtime_env "${mpi_impl}";
      fi
      petsc_runtime_env "${embedded}" "${mpi_impl}" && \
      ginkgo_runtime_env "${embedded}" "${mpi_impl}" && \
      openCARP_runtime_env "${embedded}" "${mpi_impl}" "${vect_type}" && \
      carputil_runtime_env "${embedded}" "${mpi_impl}" "${vect_type}";
      ;;
    "${spack_runtime}")
      cuda_runtime_env && \
      llvm_runtime_env && \
      spack_runtime_env "${mpi_impl}";
      ;;
    "${pluto_runtime}")
      pluto_runtime_env;
      ;;
    "${poly_runtime}")
      poly_runtime_env;
      ;;
  esac
  export PATH=".${PATH:+:${PATH}}";
  return ${?};
}

runtime_env "${@}";
