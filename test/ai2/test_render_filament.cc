

#include "CLI/CLI.hpp"
#include <array>
#include <string>


#include <mujoco/mujoco.h>

#include <CLI/CLI.hpp>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

static constexpr int WIDTH = 1028;
static constexpr int HEIGHT = 720;
static constexpr int CHANNELS = 3;

struct Args {
    std::string model_path = "";
};

struct Context {
    mjvScene scene;
    mjvCamera camera;
    mjvOption option;
    mjrContext render_ctx;
};

auto main(int argc, char** argv) -> int {
    CLI::App app("Simple test for mujoco's filament renderer");
    argv = app.ensure_utf8(argv);
    
    Args cli_args{};
    app.add_option("--model-path", cli_args.model_path, "The relative path to the model to load");
    CLI11_PARSE(app, argc, argv);

    std::array<char, 1000> error;
    auto model = mj_loadXML(cli_args.model_path.c_str(), NULL, error.data(), error.size());
    if (!model) {
        mju_error("Couldn't load model: %s", error.data());
        return 1;
    }

    auto data = mj_makeData(model);
    mj_forward(model, data);

    Context ctx{};
    mjv_defaultFreeCamera(model, &ctx.camera);
    mjv_defaultOption(&ctx.option);
    mjv_defaultScene(&ctx.scene);
    mjr_defaultContext(&ctx.render_ctx);

    mjv_makeScene(model, &ctx.scene, 1000);
    mjr_makeContext(model, &ctx.render_ctx, mjFONTSCALE_150);
    mjr_setBuffer(mjFB_OFFSCREEN, &ctx.render_ctx);

    mjrRect viewport = {0, 0, WIDTH, HEIGHT};
    mjv_updateScene(model, data, &ctx.option, nullptr, &ctx.camera, mjCAT_ALL, &ctx.scene);
    mjr_render(viewport, &ctx.scene, &ctx.render_ctx);

    std::unique_ptr<unsigned char[]> rgb_buffer(new unsigned char[CHANNELS * WIDTH * HEIGHT]);
    std::memset(rgb_buffer.get(), 0, sizeof(unsigned char) * CHANNELS * WIDTH * HEIGHT);

    mjr_readPixels(rgb_buffer.get(), nullptr, viewport, &ctx.render_ctx);


    constexpr int stride_bytes = WIDTH * CHANNELS;
    if (stbi_write_png("img_test_filament.png", WIDTH, HEIGHT, CHANNELS, rgb_buffer.get(), stride_bytes)) {
        std::printf("Successfully saved rendered image\n");
    }
    else {
        std::printf("Couldn't save rendered image\n");
    }

    mjv_freeScene(&ctx.scene);
    mjr_freeContext(&ctx.render_ctx);

    mj_deleteData(data);
    mj_deleteModel(model);

    return 0;
}









