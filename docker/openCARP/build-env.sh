#!/bin/bash

build_env() {
  src_home="${src_home:-${HOME}/src}";
  dev_home="${dev_home:-${src_home}/exascale}";

  python_runtime="${python_runtime:-python}";
  cuda_runtime="${cuda_runtime:-cuda}";
  nvhpc_runtime="${nvhpc_runtime:-nvhpc}";
  llvm_runtime="${llvm_runtime:-llvm}";
  poly_runtime="${poly_runtime:-poly}";
  pluto_runtime="${pluto_runtime:-pluto}";
  openCARP_runtime="${openCARP_runtime:-openCARP}";
  spack_runtime="${spack_runtime:-spack}";
  runtime_list="${runtime_list:-${python_runtime} ${cuda_runtime} ${nvhpc_runtime} ${llvm_runtime} ${poly_runtime} ${pluto_runtime} ${openCARP_runtime} ${spack_runtime}}";

  # python
  if [ -n "$(which python)" ];
  then
    python_version="$(python --version | cut -d' ' -f 2 | cut -d'.' -f 1-2)";
  fi
  env_name="${env_name:-openCARP}";

  gcc_type="${gcc_type:-gcc}";
  llvm_type="${llvm_type:-llvm}";
  type_list="${type_list:-${gcc_type} ${llvm_type}}";
  common_flags="${common_flags:--O3 -march=native}"; #-ffast-math -fopenmp
  common_cflags="${common_cflags:-${common_flags}}"; #-std=c17
  common_cxxflags="${common_cxxflags:-${common_flags}}"; #-std=c++20
  graphite_cflags="${graphite_cflags:--floop-nest-optimize -floop-parallelize-all}"; #-fgraphite -fopenmp
  graphite_cxxflags="${graphite_cxxflags:-${graphite_cflags}}";

  # OpenPMIx
  openpmix_repo_url="${openpmix_repo_url:-https://github.com/openpmix/openpmix.git}";
  openpmix_branch="${openpmix_branch:-v5.0.2}";
  openpmix_prefix="${openpmix_prefix:-/opt/openpmix/${openpmix_branch}}";
  openpmix_src_dir="${openpmix_src_dir:-${src_home}/openpmix/${openpmix_branch}}";

  # prrte
  prrte_repo_url="${prrte_repo_url:-https://github.com/openpmix/prrte.git}";
  prrte_branch="${prrte_branch:-v3.0.5}";
  prrte_prefix="${prrte_prefix:-/opt/prrte/${prrte_branch}}";
  prrte_src_dir="${prrte_src_dir:-${src_home}/prrte/${prrte_branch}}";

  # libfabric
  libfabric_repo_url="${libfabric_repo_url:-https://github.com/ofiwg/libfabric.git}";
  libfabric_branch="${libfabric_branch:-v1.20.1}";
  libfabric_prefix="${libfabric_prefix:-/opt/libfabric/${libfabric_branch}}";
  libfabric_src_dir="${libfabric_src_dir:-${src_home}/libfabric/${libfabric_branch}}";

  # Lightweight Communication Interface (LCI)
  lci_repo_url="${lci_repo_url:-https://github.com/uiuc-hpc/LC.git}";
  lci_branch="${lci_branch:-v1.7.6}";
  lci_prefix="${lci_prefix:-/opt/lci/${lci_branch}}";
  lci_src_dir="${lci_src_dir:-${src_home}/lci/${lci_branch}}";

  # boost
  boost_repo_url="${boost_repo_url:-https://github.com/boostorg/boost.git}";
  boost_branch="${boost_branch:-1.84.0}";
  boost_prefix="${boost_prefix:-/opt/boost/${boost_branch}}";
  boost_src_dir="${boost_src_dir:-${src_home}/boost/${boost_branch}}";

  # hwloc
  hwloc_repo_url="${hwloc_repo_url:-https://github.com/open-mpi/hwloc.git}";
  hwloc_branch="${hwloc_branch:-v2.9}";
  hwloc_prefix="${hwloc_prefix:-/opt/hwloc/${hwloc_branch}}";
  hwloc_src_dir="${hwloc_src_dir:-${src_home}/hwloc/${hwloc_branch}}";

  # ucx
  ucx_repo_url="${ucx_repo_url:-https://github.com/openucx/ucx.git}";
  ucx_branch="${ucx_branch:-v1.15.x}";
  ucx_prefix="${ucx_prefix:-/opt/ucx/${ucx_branch}}";
  ucx_src_dir="${ucx_src_dir:-${src_home}/ucx/${ucx_branch}}";

  # openmpi
  openmpi_repo_url="${openmpi_repo_url:-https://github.com/open-mpi/ompi.git}";
  openmpi_branch="${openmpi_branch:-v5.0.x}";
  openmpi_prefix="${openmpi_prefix:-/opt/openmpi/${openmpi_branch}}";
  openmpi_src_dir="${openmpi_src_dir:-${src_home}/openmpi/${openmpi_branch}}";

  # mpich
  mpich_repo_url="${mpich_repo_url:-https://github.com/pmodels/mpich.git}";
  mpich_branch="${mpich_branch:-v4.2.0}";
  mpich_prefix="${mpich_prefix:-/opt/mpich/${mpich_branch}}";
  mpich_src_dir="${mpich_src_dir:-${src_home}/mpich/${mpich_branch}}";

  # superlu_dist
  superlu_dist_repo_url="${superlu_dist_repo_url:-https://github.com/xiaoyeli/superlu_dist.git}";
  superlu_dist_branch="${superlu_dist_branch:-v8.2.1}";
  superlu_dist_prefix="${superlu_dist_prefix:-/opt/superlu_dist/${superlu_dist_branch}}";
  superlu_dist_src_dir="${superlu_dist_src_dir:-${src_home}/superlu_dist/${superlu_dist_branch}}";

  # hypre
  hypre_repo_url="${hypre_repo_url:-https://github.com/hypre-space/hypre.git}";
  hypre_branch="${hypre_branch:-v2.31.0}";
  hypre_prefix="${hypre_prefix:-/opt/hypre/${hypre_branch}}";
  hypre_src_dir="${hypre_src_dir:-${src_home}/hypre/${hypre_branch}}";

  # spack
  spack_repo_url="${spack_repo_url:-https://github.com/spack/spack.git}";
  spack_branch="${spack_branch:-develop}"; #releases/v0.21}";
  spack_src_dir="${spack_src_dir:-${src_home}/spack/${spack_branch}}";

  # solverstack spack's repo
  solverstack_spack_repo_url="${solverstack_spack_repo_url:-https://gitlab.inria.fr/solverstack/spack-repo.git}";
  solverstack_spack_src_dir="${solverstack_spack_src_dir:-${src_home}/solverstack/spack-repo}";

  # gklib, metis and parmetis
  gklib_repo_url="${gklib_repo_url:-https://github.com/KarypisLab/GKlib.git}";
  gklib_branch="${gklib_branch:-master}";
  gklib_prefix="${gklib_prefix:-/opt/gklib/${gklib_branch}}";
  gklib_src_dir="${gklib_src_dir:-${src_home}/gklib/${gklib_branch}}";
  metis_repo_url="${metis_repo_url:-https://github.com/KarypisLab/METIS.git}";
  metis_branch="${metis_branch:-master}";
  metis_prefix="${metis_prefix:-/opt/metis/${metis_branch}}";
  metis_src_dir="${metis_src_dir:-${src_home}/metis/${metis_branch}}";
  parmetis_repo_url="${parmetis_repo_url:-https://github.com/KarypisLab/ParMETIS.git}";
  parmetis_branch="${parmetis_branch:-main}";
  parmetis_prefix="${parmetis_prefix:-/opt/parmetis/${parmetis_branch}}";
  parmetis_src_dir="${parmetis_src_dir:-${src_home}/parmetis/${parmetis_branch}}";

  # blaze
  blaze_repo_url="${blaze_repo_url:-https://bitbucket.org/blaze-lib/blaze.git}";
  blaze_branch="${blaze_branch:-master}";
  blaze_prefix="${blaze_prefix:-/opt/blaze/${blaze_branch}}";
  blaze_src_dir="${blaze_src_dir:-${src_home}/blaze/${blaze_branch}}";

  # hpx
  hpx_repo_url="${hpx_repo_url:-https://github.com/STEllAR-GROUP/hpx.git}";
  hpx_branch="${hpx_branch:-v1.9.1}";
  hpx_prefix="${hpx_prefix:-/opt/hpx/${hpx_branch}}";
  hpx_src_dir="${hpx_src_dir:-${src_home}/hpx/${hpx_branch}}";

  # kokkos
  kokkos_repo_url="${kokkos_repo_url:-https://github.com/kokkos/kokkos.git}";
  kokkos_branch="${kokkos_branch:-4.3.00}";
  kokkos_prefix="${kokkos_prefix:-/opt/kokkos/${kokkos_branch}}";
  kokkos_src_dir="${kokkos_src_dir:-${src_home}/kokkos/${kokkos_branch}}";

  # kokkos kernels
  kokkos_kernels_repo_url="${kokkos_kernels_repo_url:-https://github.com/kokkos/kokkos-kernels.git}";
  kokkos_kernels_branch="${kokkos_kernels_branch:-${kokkos_branch}}";
  kokkos_kernels_prefix="${kokkos_kernels_prefix:-/opt/kokkos-kernels/${kokkos_kernels_branch}}";
  kokkos_kernels_src_dir="${kokkos_kernels_src_dir:-${src_home}/kokkos-kernels/${kokkos_kernels_branch}}";

  # scotch
  scotch_repo_url="${scotch_repo_url:-https://gitlab.inria.fr/scotch/scotch.git}";
  scotch_branch="${scotch_branch:-v7.0.4}";
  scotch_prefix="${scotch_prefix:-/opt/scotch/${scotch_branch}}";
  scotch_src_dir="${scotch_src_dir:-${src_home}/scotch/${scotch_branch}}";

  # pastix
  pastix_repo_url="${pastix_repo_url:-https://gitlab.inria.fr/solverstack/pastix.git}";
  pastix_branch="${pastix_branch:-master}"; #release-6.3.1}";
  pastix_prefix="${pastix_prefix:-/opt/pastix/${pastix_branch}}";
  pastix_src_dir="${pastix_src_dir:-${src_home}/pastix/${pastix_branch}}";

  # starpu
  starpu_repo_url="${starpu_repo_url:-https://github.com/starpu-runtime/starpu.git}";
  starpu_branch="${starpu_branch:-master}";
  starpu_prefix="${starpu_prefix:-/opt/starpu/${starpu_branch}}";
  starpu_src_dir="${starpu_src_dir:-${src_home}/starpu/${starpu_branch}}";

  # llvm
  llvm_version="${llvm_version:-15}";
  llvm_repo_url="${llvm_repo_url:-https://github.com/llvm/llvm-project.git}";
  llvm_branch="${llvm_branch:-release/${llvm_version}.x}";
  llvm_prefix="${llvm_prefix:-/opt/llvm/${llvm_branch}}";
  llvm_src_dir="${llvm_src_dir:-${src_home}/llvm/${llvm_branch}}";
  polly_cflags="${polly_cflags:--Wno-unused-command-line-argument -mllvm -polly -mllvm -polly-dependences-computeout=0 -mllvm -polly-vectorizer=stripmine -mllvm -polly-parallel}"; #-mllvm -polly-export -mllvm -polly-dot
  polly_cxxflags="${polly_cxxflags:-${polly_cflags}}"; # -mllvm -polly-position=before-vectorizer

  # cmake
  cmake_version="${cmake_version:-3.28.0}";
  cmake_file="${cmake_file:-https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-x86_64.tar.gz}";
  cmake_prefix="${cmake_prefix:-/opt/cmake/${cmake_version}}";

  # ninja
  ninja_version="${ninja_version:-1.11.1}";
  ninja_file="${ninja_file:-https://github.com/ninja-build/ninja/releases/download/v${ninja_version}/ninja-linux.zip}";
  ninja_prefix="${ninja_prefix:-${HOME}/.venv/${env_name}/bin}";

  # petsc
  petsc_repo_url="${petsc_repo_url:-https://gitlab.com/petsc/petsc.git}";
  petsc_branch="${petsc_branch:-release}"; #v3.20.4}";
  petsc_prefix="${petsc_prefix:-/opt/petsc/${petsc_branch}}";
  petsc_src_dir="${petsc_src_dir:-${src_home}/petsc/${petsc_branch}}";
  mpi_impl_list="${mpi_impl_list:-openmpi mpich}";

  # ginkgo
  ginkgo_repo_url="${ginkgo_repo_url:-https://github.com/ginkgo-project/ginkgo.git}";
  ginkgo_branch="${ginkgo_branch:-develop}"; #openCARP_backend}";
  ginkgo_prefix="${ginkgo_prefix:-/opt/ginkgo/${ginkgo_branch}}";
  ginkgo_src_dir="${ginkgo_src_dir:-${src_home}/ginkgo/${ginkgo_branch}}";

  # ginkgo-hpx
  ginkgo_hpx_repo_url="${ginkgo_hpx_repo_url:-git@github.com:tthx/ginkgo.git}";
  ginkgo_hpx_branch="${ginkgo_hpx_branch:-hpx}";
  ginkgo_hpx_prefix="${ginkgo_hpx_prefix:-/opt/ginkgo/${ginkgo_hpx_branch}}";
  ginkgo_hpx_src_dir="${ginkgo_hpx_src_dir:-${src_home}/ginkgo/${ginkgo_hpx_branch}}";

  # ssget
  ssget_repo_url="${ssget_repo_url:-https://github.com/ginkgo-project/ssget.git}";
  ssget_branch="${ssget_branch:-master}";
  ssget_src_dir="${ssget_src_dir:-${src_home}/ssget/${ssget_branch}}";

  # ginkgo polyhedral
  ginkgo_polyhedral_repo_url="${ginkgo_polyhedral_repo_url:-git@github.com:tthx/ginkgo.git}";
  ginkgo_polyhedral_branch="${ginkgo_polyhedral_branch:-polyhedral}";
  ginkgo_polyhedral_prefix="${ginkgo_polyhedral_prefix:-/opt/ginkgo/${ginkgo_polyhedral_branch}}";
  ginkgo_polyhedral_src_dir="${ginkgo_polyhedral_src_dir:-${src_home}/ginkgo/${ginkgo_polyhedral_branch}}";

  # opencarp
  opencarp_repo_url="${opencarp_repo_url:-https://git.opencarp.org/openCARP/openCARP.git}";
  opencarp_branch="${opencarp_branch:-master}"; #"ginkgo_integration";
  opencarp_prefix="${opencarp_prefix:-/opt/openCARP/${opencarp_branch}}";
  opencarp_src_dir="${opencarp_src_dir:-${src_home}/openCARP/${opencarp_branch}}";
  opencarp_version="${opencarp_version:-12.0}";
  opencarp_file="${opencarp_file:-https://git.opencarp.org/openCARP/openCARP/-/archive/v${opencarp_version}/openCARP-v${opencarp_version}.tar.bz2}";
  carputils_settings_file_dir="${carputils_settings_file_dir:-${HOME}/.config/carputils}";
  autotester_output_dir="${autotester_output_dir:-${src_home}/tests/autotester}";
  petsc_flavor="${petsc_flavor:-petsc}";
  direct_flavor="${direct_flavor:-direct}";
  pt_flavor="${pt_flavor:-pt}";
  ginkgo_flavor="${ginkgo_flavor:-ginkgo}";
  flavor_list="${flavor_list:-${petsc_flavor} ${direct_flavor} ${pt_flavor} ${ginkgo_flavor}}";
  vect_type_list="${vect_type_list:-default generic cuda kokkos}";
  generic_vect_type_list="${generic_vect_type_list:-default standard cuda kokkos mix}";

  # autotester
  autotester_repo_url="${autotester_repo_url:-https://git.opencarp.org/iam-cms/autotester.git}";
  autotester_branch="${autotester_branch:-master}";
  autotester_prefix="${autotester_prefix:-${HOME}/.local/bin}";
  autotester_src_dir="${autotester_src_dir:-${src_home}/autotester/${autotester_branch}}";

  # polygeist
  polygeist_repo_url="${polygeist_repo_url:-https://github.com/llvm/Polygeist.git}";
  polygeist_branch="${polygeist_branch:-main}";
  polygeist_prefix="${polygeist_prefix:-/opt/polygeist/${polygeist_branch}}";
  polygeist_src_dir="${polygeist_src_dir:-${src_home}/polygeist/${polygeist_branch}}";

  # openscope
  osl_repo_url="${osl_repo_url:-https://github.com/periscop/openscop.git}";
  osl_branch="${osl_branch:-0.9.6}";
  osl_prefix="${osl_prefix:-/opt/osl/${osl_branch}}";
  osl_src_dir="${osl_src_dir:-${src_home}/osl/${osl_branch}}";

  # candl
  candl_repo_url="${candl_repo_url:-https://github.com/periscop/candl.git}";
  candl_branch="${candl_branch:-master}";
  candl_prefix="${candl_prefix:-/opt/candl/${candl_branch}}";
  candl_src_dir="${candl_src_dir:-${src_home}/candl/${candl_branch}}";

  # clan
  clan_repo_url="${clan_repo_url:-https://github.com/periscop/clan.git}";
  clan_branch="${clan_branch:-master}";
  clan_prefix="${clan_prefix:-/opt/clan/${clan_branch}}";
  clan_src_dir="${clan_src_dir:-${src_home}/clan/${clan_branch}}";

  # clay
  clay_repo_url="${clay_repo_url:-https://github.com/periscop/clay.git}";
  clay_branch="${clay_branch:-master}";
  clay_prefix="${clay_prefix:-/opt/clay/${clay_branch}}";
  clay_src_dir="${clay_src_dir:-${src_home}/clay/${clay_branch}}";

  # cloog
  cloog_repo_url="${cloog_repo_url:-https://github.com/periscop/cloog.git}";
  cloog_branch="${cloog_branch:-0.21.0}";
  cloog_prefix="${cloog_prefix:-/opt/cloog/${cloog_branch}}";
  cloog_src_dir="${cloog_src_dir:-${src_home}/cloog/${cloog_branch}}";

  # piplib
  piplib_repo_url="${piplib_repo_url:-https://github.com/periscop/piplib.git}";
  piplib_branch="${piplib_branch:-master}";
  piplib_prefix="${piplib_prefix:-/opt/piplib/${piplib_branch}}";
  piplib_src_dir="${piplib_src_dir:-${src_home}/piplib/${piplib_branch}}";

  # integer set library
  isl_repo_url="${isl_repo_url:-https://repo.or.cz/isl.git}";
  isl_branch="${isl_branch:-master}";
  isl_prefix="${isl_prefix:-/opt/isl/${isl_branch}}";
  isl_src_dir="${isl_src_dir:-${src_home}/isl/${isl_branch}}";

  # polyhedral extraction tool
  pet_repo_url="${pet_repo_url:-https://repo.or.cz/pet.git}";
  pet_branch="${pet_branch:-master}";
  pet_prefix="${pet_prefix:-/opt/pet/${pet_branch}}";
  pet_src_dir="${pet_src_dir:-${src_home}/pet/${pet_branch}}";

  # pluto
  pluto_repo_url="${pluto_repo_url:-https://github.com/bondhugula/pluto.git}";
  pluto_branch="${pluto_branch:-0.12.0}";
  pluto_prefix="${pluto_prefix:-/opt/pluto/${pluto_branch}}";
  pluto_src_dir="${pluto_src_dir:-${src_home}/pluto/${pluto_branch}}";

  # musl
  musl_repo_url="${musl_repo_url:-https://git.musl-libc.org/git/musl}";
  musl_branch="${musl_branch:-master}";
  musl_prefix="${musl_prefix:-/opt/musl/${musl_branch}}";
  musl_src_dir="${musl_src_dir:-${src_home}/musl/${musl_branch}}";

  cuda_version="${cuda_version:-11.8}";
  cuda_root="${cuda_root:-/usr/local/cuda-${cuda_version}}";
  nvhpc_root="${nvhpc_root:-/opt/nvidia/hpc_sdk}";
  nvhpc_version="${nvhpc_version:-24.3}";
  return 0;
}

build_env;
