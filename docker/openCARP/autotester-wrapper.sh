#!/bin/bash

autotester_wrapper() {
  local output_filename="${1:?"${errmsg} Missing output file"}";
  local xml="${2:-OFF}";
  if [ "${xml}" == "ON" ];
  then
    xml="-M\"${output_filename}.xml\"";
  else
    xml="";
  fi
  autotester -C -X ${xml} 1>"${output_filename}.log" 2>&1;
  return 0;
}

autotester_wrapper "${@}";
