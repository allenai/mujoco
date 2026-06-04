// Copyright 2025 DeepMind Technologies Limited
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "experimental/filament/filament/object_manager.h"

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <stdexcept>
#include <memory>
#include <span>
#include <string>
#include <string_view>
#include <utility>

#include <filament/Engine.h>
#include <filament/IndirectLight.h>
#include <filament/Material.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <mujoco/mujoco.h>
#include "experimental/filament/filament/builtins.h"
#include "user/user_resource.h"
#include "user/user_util.h"

#ifdef __linux__
#include <dlfcn.h>
#include <link.h>
#endif
#ifdef __APPLE__
#include <dlfcn.h>
#include <mach-o/dyld.h>
#endif
#ifdef _WIN32
#include <windows.h>
#endif

namespace fs = std::filesystem;

// To find the mujoco library and assets when running in python bindings/
// find assets relative to the installed package.
static fs::path GetLibraryDirectory() {
#ifdef __linux__
  Dl_info info;
  if (dladdr(reinterpret_cast<void*>(GetLibraryDirectory), &info) != 0) {
    fs::path lib_path(info.dli_fname);
    return lib_path.parent_path();
  }
#elif defined(__APPLE__)
  Dl_info info;
  if (dladdr(reinterpret_cast<void*>(GetLibraryDirectory), &info) != 0) {
    fs::path lib_path(info.dli_fname);
    return lib_path.parent_path();
  }
#elif defined(_WIN32)
  HMODULE hModule = nullptr;
  if (GetModuleHandleExA(
          GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
              GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
          reinterpret_cast<LPCSTR>(&GetLibraryDirectory), &hModule)) {
    char path[MAX_PATH];
    if (GetModuleFileNameA(hModule, path, MAX_PATH) != 0) {
      fs::path lib_path(path);
      return lib_path.parent_path();
    }
  }
#endif
  return fs::path();
}

namespace mujoco {

std::string ResolveFilamentAssetPath(const std::string& filename) {
  std::string prefix_dir = "";

  auto envvar_install_dir = std::getenv("MUJOCO_INSTALL_DIR");
  if (!envvar_install_dir) {
    auto lib_dir = GetLibraryDirectory();
    auto assets_dir = lib_dir / "filament" / "assets" / "data";
    if (fs::is_directory(assets_dir)) {
      prefix_dir = assets_dir.string() + "/";
    }
  }
  else {
    fs::path install_dir(envvar_install_dir);
    auto assets_dir = install_dir / "filament" / "assets";
    if (fs::is_directory(assets_dir)) {
      prefix_dir = assets_dir.string() + "/";
    }
  }

  return std::string(user::FilePath(prefix_dir, filename).c_str());
}

static filament::Material* LoadMaterial(filament::Engine* engine,
                                        std::string_view filename) {
  const std::string path = ResolveFilamentAssetPath(std::string(filename));

  mjResource* resource = nullptr;
  void* payload = nullptr;
  std::array<char, 1000> error;

  resource = mju_openResource("", path.c_str(), nullptr, error.data(), error.size());

  if (!resource) {
    mju_error("Error while opening resource > %s", error.data());
    throw std::runtime_error("Got an error while loading a file when loading filament materials.");
  }

  int size = mju_readResource(resource, const_cast<const void**>(&payload));
  filament::Material::Builder material_builder;
  material_builder.package(payload, size);
  filament::Material* material = material_builder.build(*engine);
  mju_closeResource(resource);
  return material;
};

ObjectManager::ObjectManager(filament::Engine* engine)
    : engine_(engine) {
  materials_[kPbr] = LoadMaterial(engine, "pbr.filamat");
  materials_[kPbrPacked] = LoadMaterial(engine, "pbr_packed.filamat");
  materials_[kPbrTransparent] = LoadMaterial(engine, "pbr_transparent.filamat");
  materials_[kPbrPackedTransparent] = LoadMaterial(engine, "pbr_packed_transparent.filamat");
  materials_[kPhong2d] = LoadMaterial(engine, "phong_2d.filamat");
  materials_[kPhong2dFade] = LoadMaterial(engine, "phong_2d_fade.filamat");
  materials_[kPhong2dReflect] = LoadMaterial(engine, "phong_2d_reflect.filamat");
  materials_[kPhong2dUv] = LoadMaterial(engine, "phong_2d_uv.filamat");
  materials_[kPhong2dUvFade] = LoadMaterial(engine, "phong_2d_uv_fade.filamat");
  materials_[kPhong2dUvReflect] = LoadMaterial(engine, "phong_2d_uv_reflect.filamat");
  materials_[kPhongColor] = LoadMaterial(engine, "phong_color.filamat");
  materials_[kPhongColorFade] = LoadMaterial(engine, "phong_color_fade.filamat");
  materials_[kPhongColorReflect] = LoadMaterial(engine, "phong_color_reflect.filamat");
  materials_[kPhongCube] = LoadMaterial(engine, "phong_cube.filamat");
  materials_[kPhongCubeFade] = LoadMaterial(engine, "phong_cube_fade.filamat");
  materials_[kPhongCubeReflect] = LoadMaterial(engine, "phong_cube_reflect.filamat");
  materials_[kUnlitSegmentation] = LoadMaterial(engine, "unlit_segmentation.filamat");
  materials_[kUnlitDecor] = LoadMaterial(engine, "unlit_decor.filamat");
  materials_[kUnlitDepth] = LoadMaterial(engine, "unlit_depth.filamat");
  materials_[kUnlitUi] = LoadMaterial(engine, "unlit_ui.filamat");

  static uint8_t black_rgb[3] = {0, 0, 0};
  static uint8_t white_rgb[3] = {255, 255, 255};
  static uint8_t normal_data[3] = {128, 128, 255};
  static uint8_t orm_data[3] = {0, 255, 0};

  auto CreateFallbackTexture = [this](uint8_t color[3]) {
    filament::Texture::Builder builder;
    builder.width(1);
    builder.height(1);
    builder.format(filament::Texture::InternalFormat::RGB8);
    builder.sampler(filament::Texture::Sampler::SAMPLER_2D);
    filament::Texture* texture = builder.build(*engine_);
    const filament::Texture::Type type = filament::Texture::Type::UBYTE;
    const filament::Texture::Format format = filament::Texture::Format::RGB;
    texture->setImage(*engine_, 0, {color, 3, format, type});
    return texture;
  };

  fallback_black_ = CreateFallbackTexture(black_rgb);
  fallback_white_ = CreateFallbackTexture(white_rgb);
  fallback_normal_ = CreateFallbackTexture(normal_data);
  fallback_orm_ = CreateFallbackTexture(orm_data);

  fallback_textures_[mjTEXROLE_USER] = fallback_black_;
  fallback_textures_[mjTEXROLE_RGB] = fallback_white_;
  fallback_textures_[mjTEXROLE_OPACITY] = fallback_white_;
  fallback_textures_[mjTEXROLE_OCCLUSION] = fallback_white_;
  fallback_textures_[mjTEXROLE_ROUGHNESS] = fallback_white_;
  fallback_textures_[mjTEXROLE_METALLIC] = fallback_black_;
  fallback_textures_[mjTEXROLE_NORMAL] = fallback_normal_;
  fallback_textures_[mjTEXROLE_EMISSIVE] = fallback_black_;
  fallback_textures_[mjTEXROLE_ORM] = fallback_orm_;
}

ObjectManager::~ObjectManager() {
  engine_->destroy(fallback_black_);
  engine_->destroy(fallback_white_);
  engine_->destroy(fallback_normal_);
  engine_->destroy(fallback_orm_);
  for (auto& iter : materials_) {
    engine_->destroy(iter);
  }
}

filament::Material* ObjectManager::GetMaterial(MaterialType type) const {
  if (type < 0 || type >= kNumMaterials) {
    mju_error("Invalid material type: %d", type);
  }
  return materials_[type];
}

Builtins* ObjectManager::GetBuiltins(int nstack, int nslice, int nquad) {
  // Assumes nstack, nslice, and nquad are non-negative and less than 2^20.
  std::uint64_t key = (static_cast<uint64_t>(nstack) << 20) |
                      (static_cast<uint64_t>(nslice) << 40) |
                      static_cast<uint64_t>(nquad);

  auto iter = builtins_.find(key);
  if (iter == builtins_.end()) {
    auto builtins = std::make_unique<Builtins>(engine_, nstack, nslice, nquad);
    Builtins* ptr = builtins.get();
    builtins_[key] = std::move(builtins);
    return ptr;
  }
  return iter->second.get();
}

const filament::Texture* ObjectManager::GetFallbackTexture(
    mjtTextureRole role) const {
  if (role < 0 || role >= mjNTEXROLE) {
    mju_error("Invalid texture role: %d", role);
  }
  return fallback_textures_[role];
}
}  // namespace mujoco
