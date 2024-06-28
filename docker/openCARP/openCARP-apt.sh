#!/bin/bash
set -euo pipefail;

llvm_install() {
  local distribution="$(lsb_release -cs)";
  local pkg="libllvm-${llvm_version}-ocaml-dev libllvm${llvm_version} llvm-${llvm_version} llvm-${llvm_version}-dev llvm-${llvm_version}-doc llvm-${llvm_version}-examples llvm-${llvm_version}-runtime clang-${llvm_version} clang-tools-${llvm_version} clang-${llvm_version}-doc libclang-common-${llvm_version}-dev libclang-${llvm_version}-dev libclang1-${llvm_version} clang-format-${llvm_version} python3-clang-${llvm_version} clangd-${llvm_version} clang-tidy-${llvm_version} libclang-rt-${llvm_version}-dev libpolly-${llvm_version}-dev libfuzzer-${llvm_version}-dev lldb-${llvm_version} lld-${llvm_version} libc++-${llvm_version}-dev libc++abi-${llvm_version}-dev libomp-${llvm_version}-dev libclc-${llvm_version}-dev libunwind-${llvm_version}-dev libmlir-${llvm_version}-dev mlir-${llvm_version}-tools libbolt-${llvm_version}-dev bolt-${llvm_version} flang-${llvm_version}";
  if [ "$(lsb_release -r|cut -d':' -f 2|cut -d'.' -f 1)" -gt 20 ];
  then
    pkg+=" libclang-rt-${llvm_version}-dev-wasm32 libclang-rt-${llvm_version}-dev-wasm64 libc++-${llvm_version}-dev-wasm32 libc++abi-${llvm_version}-dev-wasm32 libclang-rt-${llvm_version}-dev-wasm32 libclang-rt-${llvm_version}-dev-wasm64";
  fi
  wget -q "https://apt.llvm.org/llvm-snapshot.gpg.key" \
    -O /usr/share/keyrings/apt.llvm.org.asc;
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/apt.llvm.org.asc] http://apt.llvm.org/${distribution}/ llvm-toolchain-${distribution}-${llvm_version} main" | \
    tee "/etc/apt/sources.list.d/llvm-${llvm_version}.list" > /dev/null;
  apt update;
  apt -y --no-install-recommends install ${pkg};
  return ${?};
}

cuda_install() {
  local distribution="${1:-ubuntu2204}";
  local arch="${2:-x86_64}";
  apt update;
  apt -y install wget gnupg;
  apt-key del 7fa2af80;
  wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/${arch}/cuda-archive-keyring.gpg" \
    -O /usr/share/keyrings/cuda-archive-keyring.gpg;
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/${arch}/ /" | \
    tee /etc/apt/sources.list.d/nvidia.list > /dev/null;
  wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/${arch}/cuda-${distribution}.pin" \
    -O /etc/apt/preferences.d/cuda-repository-pin-600;
  apt update;
  apt install -y --no-install-recommends "cuda-toolkit-${cuda_version/\./-}";
  return ${?};
}

nvhpc_install() {
  wget -qO - "https://developer.download.nvidia.com/hpc-sdk/ubuntu/DEB-GPG-KEY-NVIDIA-HPC-SDK" | \
    gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-hpcsdk-archive-keyring.gpg;
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nvidia-hpcsdk-archive-keyring.gpg] https://developer.download.nvidia.com/hpc-sdk/ubuntu/amd64 /" | \
    tee /etc/apt/sources.list.d/nvhpc.list > /dev/null;
  apt update;
  apt install -y --no-install-recommends nvhpc-24-3-cuda-multi;
  return ${?};
}

openCARP_apt() {
  local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE}")")";
  local task_based="build-essential autoconf coreutils environment-modules gpg zip vim libpciaccess0 libpciaccess-dev libxnvctrl-dev libudev-dev libgoogle-perftools-dev libasio-dev libopenblas-serial-dev libgtest-dev libzstd-dev libbz2-dev libmpfr-dev libmpfrc++-dev libeigen3-dev libmpfi-dev libtommath-dev libnuma-dev"; #libpmi0-dev libpmi2-0-dev libpmix-dev";
  local openmpi="openmpi-bin openmpi-common libopenmpi-dev";
  local starpu="doxygen doxygen-gui doxygen-doc libstarpu-dev starpu-tools starpu-examples";
  local pluto="texinfo libyaml-dev libgmp3-dev glpk-utils libglpk-dev";
  local gcc_version="12";
  local gcc="gcc-${gcc_version} g++-${gcc_version} gfortran-${gcc_version} cc-${gcc_version}-multilib g++-${gcc_version}-multilib gfortran-${gcc_version}-multilib";
  local mpich="libpsm-infinipath1-dev libpsm2-dev librdmacm-dev libibverbs-dev";
  export DEBIAN_FRONTEND="noninteractive";
  . "${script_dir}/build-env.sh";
  apt update;
  apt -y dist-upgrade;
  apt -y install \
    lsb-release \
    ca-certificates \
    cmake \
    curl \
    file \
    g++ gfortran \
    gcc-multilib g++-multilib gfortran-multilib \
    patch \
    gengetopt \
    git \
    make \
    pkg-config \
    ssh \
    valgrind \
    unzip \
    ninja-build \
    wget \
    binutils-gold \
    libfftw3-dev \
    libgomp1 \
    zlib1g-dev \
    libjpeg-dev \
    libhdf5-dev \
    libtool-bin \
    python3 \
    python-is-python3 \
    python3-dev \
    python-dev-is-python3 \
    python3-venv \
    python3-distutils \
    libffi-dev libelf-dev libelfin-dev \
    flex bison \
    ccache \
    ${pluto} \
    ${task_based} \
    ${mpich};
  cuda_install;
  apt update;
  apt -y dist-upgrade;
  if [ ! -d "${HOME}/.venv/${env_name}" ];
  then
    python -m venv "${HOME}/.venv/${env_name}";
  fi
  . "${HOME}/.venv/${env_name}/bin/activate";
  ln -sf /usr/include/python3.10 "${HOME}/.venv/${env_name}/include/.";
  pip install --upgrade --no-cache-dir pip;
  pip install --upgrade --no-cache-dir \
    setuptools \
    tk \
    wheel \
    matplotlib \
    numpy \
    pandas \
    scipy \
    tables \
    pybind11 \
    PyYAML \
    dataclasses;
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;
  . "${script_dir}/get-cmake.sh";
  wget -q "${ninja_file}" \
    -O /tmp/ninja.zip;
  unzip /tmp/ninja.zip -d "${ninja_prefix}";
  rm -f /tmp/ninja.zip;
  return ${?};
}

openCARP_apt;
