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

backup() {
  local autotester_dir="${1}";
  local devtests_dir="${2}";
  if [ -f "${autotester_dir}/atc_template_bidomain.py" ];
  then
    cp -f "${autotester_dir}/atc_template_bidomain.py" \
      "${autotester_dir}/atc_template_bidomain.py.orig";
  fi
  if [ -f "${devtests_dir}/bidomain/phie_recovery/run.py" ];
  then
    cp -f "${devtests_dir}/bidomain/phie_recovery/run.py" \
      "${devtests_dir}/bidomain/phie_recovery/run.py.orig";
  fi
  if [ -f "${devtests_dir}/LIMPET/em_coupling/run.py" ];
  then
    cp -f "${devtests_dir}/LIMPET/em_coupling/run.py" \
      "${devtests_dir}/LIMPET/em_coupling/run.py.orig";
  fi
  if [ -f "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py" ];
  then
    cp -f "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py" \
      "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py.orig";
  fi
  if [ -f "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py" ];
  then
    cp -f "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py" \
      "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py.orig";
  fi
  if [ -f "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py" ];
  then
    cp -f "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py" \
      "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py.orig";
  fi
  return 0;
}

restore() {
  local autotester_dir="${1}";
  local devtests_dir="${2}";
  if [ -f "${autotester_dir}/atc_template_bidomain.py.orig" ];
  then
    mv -f "${autotester_dir}/atc_template_bidomain.py.orig" \
      "${autotester_dir}/atc_template_bidomain.py";
  fi
  if [ -f "${devtests_dir}/bidomain/phie_recovery/run.py.orig" ];
  then
    mv -f "${devtests_dir}/bidomain/phie_recovery/run.py.orig" \
      "${devtests_dir}/bidomain/phie_recovery/run.py";
  fi
  if [ -f "${devtests_dir}/LIMPET/em_coupling/run.py.orig" ];
  then
    mv -f "${devtests_dir}/LIMPET/em_coupling/run.py.orig" \
      "${devtests_dir}/LIMPET/em_coupling/run.py";
  fi
  if [ -f "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py.orig" ];
  then
    mv -f "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py.orig" \
      "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py";
  fi
  if [ -f "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py.orig" ];
  then
    mv -f "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py.orig" \
      "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py";
  fi
  if [ -f "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py.orig" ];
  then
    mv -f "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py.orig" \
      "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py";
  fi
  return 0;
}

apply_patches() {
  local autotester_dir="${1}";
  local devtests_dir="${2}";
  local vect_type="${3}";
  local generic_vect_type="${4}";
  local info="${5}";
  local new_dir="${dev_home}/openCARP/${opencarp_branch}/external/experiments";
  local new_autotester_dir="${new_dir}/autotester";
  local new_devtests_dir="${new_dir}/regression/devtests";
  if [ "${vect_type}" == "generic" ];
  then
    case "${generic_vect_type}" in
      "default")
        vect_type="";
        ;;
      "standard"|"cuda"|"kokkos"|"mix")
        vect_type="${generic_vect_type}";
        ;;
    esac
  else
    vect_type="";
  fi
  if [ -n "${vect_type}" ] || [ -n "${info}" ];
  then
    cp -f "${new_autotester_dir}/atc_template_bidomain${info:+.${info}}${vect_type:+.${vect_type}}.py" \
      "${autotester_dir}/atc_template_bidomain.py";
    cp -f "${new_devtests_dir}/LIMPET/em_coupling/run${info:+.${info}}${vect_type:+.${vect_type}}.py" \
      "${devtests_dir}/LIMPET/em_coupling/run.py";
    cp -f "${new_devtests_dir}/LIMPET/ionic_model/LIMPET_IM${info:+.${info}}${vect_type:+.${vect_type}}.py" \
      "${devtests_dir}/LIMPET/ionic_model/LIMPET_IM.py";
    cp -f "${new_devtests_dir}/LIMPET/plugin/LIMPET_PL${info:+.${info}}${vect_type:+.${vect_type}}.py" \
      "${devtests_dir}/LIMPET/plugin/LIMPET_PL.py";
    cp -f "${new_devtests_dir}/LIMPET/stim_assign/LIMPET_SA${info:+.${info}}${vect_type:+.${vect_type}}.py" \
      "${devtests_dir}/LIMPET/stim_assign/LIMPET_SA.py";
    cp -f "${new_devtests_dir}/bidomain/phie_recovery/run.py" \
      "${devtests_dir}/bidomain/phie_recovery/run.py";
  fi
  return 0;
}

regression_test() {
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
    echo "Usage: ${BASH_SOURCE} [embedded] <petsc|ginkgo> <${mpi_impl_list//\ /\|}> <${vect_type_list//\ /\|}> [${generic_vect_type_list//\ /\|}] [info] [count] [xml]";
    return 0;
  fi
  local flavor="${1:?"${errmsg} Missing flavor"}";
  check_flavor "${flavor}";
  local mpi_impl="${2:?"${errmsg} Missing MPI implementation, supported are: [${mpi_impl_list//\ /,\ }]"}";
  check_mpi_impl "${mpi_impl}";
  local vect_type="${3:?"${errmsg} Missing vector/matrix type, supported are: [${vect_type_list//\ /,\ }]"}";
  check_vect_type "${vect_type}";
  local generic_vect_type="";
  local i;
  local r;
  if [ "${vect_type}" == "generic" ];
  then
    if [ ${#} -gt 3 ];
    then
      r=0;
      generic_vect_type="${4}";
      for i in ${generic_vect_type_list};
      do
        if [ "${i}" == "${generic_vect_type}" ];
        then
          r=1;
          break;
        fi
      done
      if [ ${r} -eq 0 ];
      then
        echo "${errmsg} \"${generic_vect_type}\" is not a supported vector/matrix.";
        echo "${errmsg} Only [${generic_vect_type_list//\ /,\ }] are available."
        return 1;
      fi
      shift;
    fi
  fi
  local info="${4:+info}";
  local count="${5:-1}";
  local xml="${6:-OFF}";
  local output_filename;
  if [ -z "$(which autotester)" ];
  then
    echoerr "${errmsg} No autotester found.";
    return 1;
  fi
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
  mkdir -p "${autotester_output_dir}";
  if [ "${xml}" == "ON" ];
  then
    mkdir -p "${autotester_output_dir}/transformation";
    cp -rf "${autotester_src_dir}/transformation/css" \
      "${autotester_output_dir}/transformation/.";
    cp -rf "${autotester_src_dir}/transformation/js" \
      "${autotester_output_dir}/transformation/.";
  fi
  local experiments_dir="${opencarp_src_dir}/external/experiments";
  local autotester_dir="${experiments_dir}/autotester";
  local devtests_dir="${experiments_dir}/regression/devtests";
  restore "${autotester_dir}" "${devtests_dir}";
  backup "${autotester_dir}" "${devtests_dir}";
  apply_patches "${autotester_dir}" "${devtests_dir}" "${vect_type}" "${generic_vect_type}" "${info}";
  cd "${autotester_dir}";
  python ./atc_template_limpet.py;
  python ./atc_template_bidomain.py --flavor "${flavor}";
  cd "${experiments_dir}";
  i=1;
  while [ ${i} -le ${count} ];
  do
    printf "Starting regression tests[%d/%d]: flavor=[%s]={...\n...\n" \
      "${i}" "${count}" \
      "${flavor}";
    output_filename="${autotester_output_dir}/autotester-${flavor}-$(date +%F\ %T)";
    "${script_dir}/autotester-wrapper.sh" \
      "${output_filename}" "${xml}";
    if [ "${xml}" == "ON" ];
    then
      xsltproc "${autotester_src_dir}/transformation/html.xsl" \
        "${output_filename}.xml" > \
        "${output_filename}.html";
    fi
    printf "...}=Regression tests finished[%d/%d]: flavor=[%s].\n" \
      "${i}" "${count}" \
      "${flavor}";
    i=$((i+1));
  done
  restore "${autotester_dir}" "${devtests_dir}";
  return 0;
}

regression_test "${@}";
