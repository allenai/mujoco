#!/usr/bin/env bash

set -e

build_type="Release"

echo "Going back to the root of the project"
ROOT_DIR="$(git rev-parse --show-toplevel)"

cd ${ROOT_DIR}

SHOW_HELP=false
build_filament=OFF
build_with_vulkan=OFF
build_studio=OFF
build_simulate=ON
install_dir=""
njobs=4

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) SHOW_HELP=true; shift ;;
        --debug) build_type="Debug"; shift ;;
        --filament) build_filament=ON; shift ;;
        --vulkan) build_with_vulkan=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --njobs) njobs="$2"; shift 2 ;;
        --install-dir) install_dir="$2"; shift 2 ;;
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

if [[ "${build_filament}" == "ON" ]]; then
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    build_simulate=OFF
fi

[[ -n $install_dir ]] && USER_INSTALL_DIR="${install_dir}" || USER_INSTALL_DIR="${ROOT_DIR}/install"

if [ ! -d "${USER_INSTALL_DIR}" ]; then
    mkdir -p $USER_INSTALL_DIR
fi

echo "Configuring ..."
CMAKE_CONFIG_ARGS=(
    "-DCMAKE_BUILD_TYPE=${build_type}"
    "-DUSE_STATIC_LIBCXX=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DMUJOCO_BUILD_EXAMPLES=OFF"
    "-DMUJOCO_BUILD_SIMULATE=${build_simulate}"
    "-DMUJOCO_BUILD_TESTS=OFF"
    "-DMUJOCO_WITH_USD=OFF"
    "-DMUJOCO_TEST_AI2=ON"
    "-DMUJOCO_USE_FILAMENT_MJR_COMPAT=${build_filament}"
    "-DMUJOCO_USE_FILAMENT=${build_filament}"
    "-DMUJOCO_USE_FILAMENT_VULKAN=${build_with_vulkan}"
    "-DFILAMENT_SUPPORTS_VULKAN=${build_with_vulkan}"
    "-DFILAMENT_SUPPORTS_METAL=OFF"
    "-DMUJOCO_BUILD_STUDIO=${build_studio}"
    "-DCMAKE_INSTALL_PREFIX=${USER_INSTALL_DIR}"
    "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
)

if [[ -n "${CMAKE_ARGS}" ]]; then
    read -a cmake_args_arr <<<"$CMAKE_ARGS"
    CMAKE_CONFIG_ARGS+=("${cmake_args_arr[@]}")
fi

cmake -B build "${CMAKE_CONFIG_ARGS[@]}"

echo "Building ..."

cmake --build build --config="${build_type}" --parallel ${njobs}

echo "Installing to target dir ..."

cmake --install build

echo "Copy plugins to install directory"

mkdir -p ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libactuator.* ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libelasticity.* ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libobj_decoder.* ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libstl_decoder.* ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsensor.* ${USER_INSTALL_DIR}/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsdf_plugin.* ${USER_INSTALL_DIR}/mujoco_plugin

if [[ "${build_filament}" == "ON" ]]; then
    echo "Copy filament assets to install directory"
    mkdir -p ${USER_INSTALL_DIR}/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.filamat ${USER_INSTALL_DIR}/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.ktx ${USER_INSTALL_DIR}/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.ttf ${USER_INSTALL_DIR}/filament/assets
fi
