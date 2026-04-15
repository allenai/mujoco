#include <cstdio>
#include <cstring>

#include <array>
#include <filesystem>
#include <string>

#include <mujoco/mujoco.h>

#include <CLI/CLI.hpp>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

namespace fs = std::filesystem;

static constexpr int WIDTH = 1280;
static constexpr int HEIGHT = 720;
static constexpr int CHANNELS = 3;

bool USE_RGB = false;

auto main(int argc, char** argv) -> int {
  CLI::App app("Simple test for mujoco's segmentation rendering");
  argv = app.ensure_utf8(argv);

  app.add_option("--rgb", USE_RGB, "Whether or not to render in normal rgb mode");

  CLI11_PARSE(app, argc, argv);

  fs::path current_path = __FILE__;
  auto model_path = current_path.parent_path().parent_path().parent_path() / "model" / "humanoid" / "humanoid.xml";

  std::printf("model-path: %s\n", model_path.c_str());

  std::array<char, 1000> err;
  auto model = mj_loadXML(model_path.c_str(), NULL, err.data(), 1000);
  if (!model) {
    mju_error("Load model error: %s", err.data());
    return 1;
  }

  auto data = mj_makeData(model);
  mj_forward(model, data);

  mjvScene scene;
  mjvCamera camera;
  mjvOption option;
  mjrContext context;

  // mjv_defaultCamera(&camera);
  mjv_defaultFreeCamera(model, &camera);
  mjv_defaultOption(&option);
  mjv_defaultScene(&scene);
  mjr_defaultContext(&context);

  mjv_makeScene(model, &scene, 2000);
  mjr_makeContext(model, &context, mjFONTSCALE_150);
  mjr_setBuffer(mjFB_OFFSCREEN, &context);

  if (!USE_RGB) {
      scene.flags[mjRND_SEGMENT] = 1;
      scene.flags[mjRND_IDCOLOR] = 1;
  }

  mjrRect viewport = {0, 0, WIDTH, HEIGHT};
  mjv_updateScene(model, data, &option, NULL, &camera, mjCAT_ALL, &scene);
  mjr_render(viewport, &scene, &context);

  std::unique_ptr<unsigned char[]> rgb_buffer(new unsigned char[CHANNELS * WIDTH * HEIGHT]);
  std::memset(rgb_buffer.get(), 0, sizeof(unsigned char) * CHANNELS * WIDTH * HEIGHT);

  mjr_readPixels(rgb_buffer.get(), nullptr, viewport, &context);

  std::string png_filepath = USE_RGB ? "normal.png" : "segmentation.png";

  int stride_bytes = WIDTH * CHANNELS;
  if (stbi_write_png(png_filepath.c_str(), WIDTH, HEIGHT, CHANNELS, rgb_buffer.get(), stride_bytes)) {
    std::printf("Successfully saved rendered image\n");
  }
  else {
    std::printf("Couldn't save rendered image\n");
  }

  mjv_freeScene(&scene);
  mjr_freeContext(&context);

  mj_deleteData(data);
  mj_deleteModel(model);

  return 0;
}
