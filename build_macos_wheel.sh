#!/usr/bin/env bash

set +e

git status > /dev/null 2>&1
if [ $? -ne 0 ]; then
    ROOT_DIR=$(pwd)
else
    echo "Going back to the root of the project"
    ROOT_DIR="$(git rev-parse --show-toplevel)"
fi

set -e

build_type="Release"

cd ${ROOT_DIR}

if [ ! -d "${ROOT_DIR}/install" ]; then
    mkdir install
fi

SHOW_HELP=false
build_filament=OFF
build_with_vulkan=OFF
build_studio=OFF
build_simulate=ON
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

[[ -n $install_dir ]] && USER_INSTALL_DIR="${install_dir}" || USER_INSTALL_DIR="${ROOT_DIR}/install"

if [ ! -d "${USER_INSTALL_DIR}" ]; then
    mkdir -p $USER_INSTALL_DIR
fi

if [[ "${build_filament}" == "ON" ]]; then
    build_simulate=OFF
    build_studio=ON
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
    "-DMUJOCO_USE_FILAMENT=${build_filament}"
    "-DMUJOCO_USE_FILAMENT_MJR_COMPAT=OFF"
    "-DMUJOCO_USE_FILAMENT_VULKAN=OFF"
    "-DFILAMENT_SUPPORTS_VULKAN=OFF"
    "-DFILAMENT_SUPPORTS_METAL=OFF"
    "-DMUJOCO_BUILD_STUDIO=${build_studio}"
    "-DCMAKE_INSTALL_PREFIX=${USER_INSTALL_DIR}"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    # Several dependencies generate deprecated warnings on MacOS.
    "-DCMAKE_CXX_FLAGS=\"-Wno-error=deprecated-declarations\""
    # This flag defines _ITERATOR_DEBUG_LEVEL=0 which conflicts with debug builds
    "-DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF"
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
cp ${ROOT_DIR}/build/lib/lib*.a ${ROOT_DIR}/install/lib
cp ${ROOT_DIR}/build/lib/libactuator.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libelasticity.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsensor.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsdf_plugin.* ${ROOT_DIR}/install/mujoco_plugin

echo "Make source distribution"

bash ${ROOT_DIR}/python/make_sdist_macos.sh

echo "Build python wheel"

export MUJOCO_PATH="${ROOT_DIR}/install"
export MUJOCO_PLUGIN_PATH="${ROOT_DIR}/install/mujoco_plugin"

uv build -v --wheel --force-pep517 ${ROOT_DIR}/python/dist/mujoco-*.tar.gz --out-dir ${ROOT_DIR}/python/dist

# Clean install dir afterwards, to avoid being used as default search path
rm -rf ${USER_INSTALL_DIR}

