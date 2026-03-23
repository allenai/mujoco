#!/usr/bin/env bash

set -e

build_type="Release"

echo "Going back to the root of the project"
ROOT_DIR="$(pwd)"

cd ${ROOT_DIR}

if [ ! -d "${ROOT_DIR}/install" ]; then
    mkdir install
fi

SHOW_HELP=false
build_filament=OFF
build_with_vulkan=OFF
build_studio=OFF
build_simulate=ON
py_version="py310"
njobs=4

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) SHOW_HELP=true; shift ;;
        --debug) build_type="Debug"; shift ;;
        --filament) build_filament=ON; shift ;;
        --vulkan) build_with_vulkan=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --py-version) py_version="$2"; shift 2 ;;
        --njobs) njobs="$2"; shift 2 ;;
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

if [[ "${build_filament}" == "ON" ]]; then
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    build_simulate=OFF
    build_studio=ON
fi

py_bin="/opt/python/cp310-cp310/bin/python"
case $py_version in
    py310) py_bin="/opt/python/cp310-cp310/bin/python" ;;
    py311) py_bin="/opt/python/cp311-cp311/bin/python" ;;
    py312) py_bin="/opt/python/cp312-cp312/bin/python" ;;
    py313) py_bin="/opt/python/cp313-cp313/bin/python" ;;
    py314) py_bin="/opt/python/cp314-cp314/bin/python" ;;
esac

echo "Configuring ..."
CMAKE_CONFIG_ARGS=(
    "-DCMAKE_BUILD_TYPE=${build_type}"
    "-DUSE_STATIC_LIBCXX=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DMUJOCO_BUILD_EXAMPLES=OFF"
    "-DMUJOCO_BUILD_SIMULATE=${build_simulate}"
    "-DMUJOCO_BUILD_TESTS=OFF"
    "-DMUJOCO_WITH_USD=OFF"
    "-DMUJOCO_TEST_AI2=OFF"
    "-DMUJOCO_USE_FILAMENT=${build_filament}"
    "-DMUJOCO_USE_FILAMENT_MJR_COMPAT=${build_filament}"
    "-DMUJOCO_USE_FILAMENT_VULKAN=${build_with_vulkan}"
    "-DMUJOCO_BUILD_STUDIO=${build_studio}"
    "-DCMAKE_INSTALL_PREFIX=install"
    "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF"
    "-DCMAKE_INSTALL_LIBDIR=lib"
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

mkdir -p install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libactuator.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libelasticity.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libobj_decoder.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libstl_decoder.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsensor.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsdf_plugin.* ${ROOT_DIR}/install/mujoco_plugin

if [[ "${build_filament}" == "ON" ]]; then
    echo "Copy filament assets to install directory"
    mkdir -p install/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.filamat ${ROOT_DIR}/install/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.ktx ${ROOT_DIR}/install/filament/assets
    cp ${ROOT_DIR}/build/bin/assets/*.ttf ${ROOT_DIR}/install/filament/assets
fi

echo "Make source distribution"

bash ${ROOT_DIR}/python/make_sdist_manylinux.sh --py-version $py_version

echo "Build python wheel"

export MUJOCO_PATH="${ROOT_DIR}/install"
export MUJOCO_PLUGIN_PATH="${ROOT_DIR}/install/mujoco_plugin"

MUJOCO_CMAKE_ARGS=""

MUJOCO_FILAMENT_ASSETS=""
if [[ "${build_filament}" == "ON" ]]; then
    MUJOCO_FILAMENT_ASSETS="${ROOT_DIR}/install/filament/assets"
fi

MUJOCO_CMAKE_ARGS="${MUJOCO_CMAKE_ARGS}" MUJOCO_FILAMENT_ASSETS="${MUJOCO_FILAMENT_ASSETS}" ${py_bin} -m pip wheel --use-pep517 -vvv ${ROOT_DIR}/python/dist/mujoco_filament-*.tar.gz --wheel-dir ${ROOT_DIR}/python/dist

auditwheel repair --wheel-dir ${ROOT_DIR}/python/dist ${ROOT_DIR}/python/dist/mujoco_filament-*.whl
