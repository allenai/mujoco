from dataclasses import dataclass
from pathlib import Path

import mujoco as mj
import numpy as np
import tyro
from tqdm import tqdm


@dataclass
class Args:
    filepath: Path


class Renderer:
    def __init__(self, model: mj.MjModel, width: int, height: int) -> None:
        self._mj_model = model
        self._mj_scene = mj.MjvScene(model=model, maxgeom=10000)
        self._mj_option = mj.MjvOption()

        self._width = width
        self._height = height

        self._mjr_context = mj.MjrContext(model, mj.mjtFontScale.mjFONTSCALE_150)
        mj.mjr_setBuffer(mj.mjtFramebuffer.mjFB_OFFSCREEN, self._mjr_context)

    def update(
        self,
        data: mj.MjData,
        camera: int | str | mj.MjvCamera = -1,
        option: mj.MjvOption | None = None,
    ) -> None:
        mjv_camera: mj.MjvCamera | None = None
        if not isinstance(camera, mj.MjvCamera):
            camera_id: int = -1
            if isinstance(camera, str):
                camera_id = mj.mj_name2id(
                    self._mj_model, mj.mjtObj.mjOBJ_CAMERA, camera
                )
                if camera_id == -1:
                    raise ValueError(f"The camera '{camera}' doesn't exist")
            elif 0 <= camera < self._mj_model.ncam:
                camera_id = camera

            mjv_camera = mj.MjvCamera()
            mjv_camera.fixedcamid = camera_id

            if camera_id == -1:
                mjv_camera.type = mj.mjtCamera.mjCAMERA_FREE
                mj.mjv_defaultFreeCamera(self._mj_model, mjv_camera)
            else:
                mjv_camera.type = mj.mjtCamera.mjCAMERA_FIXED
        else:
            mjv_camera = camera

        option = option or self._mj_option
        mj.mjv_updateScene(
            self._mj_model,
            data,
            option,
            None,
            mjv_camera,
            mj.mjtCatBit.mjCAT_ALL,
            self._mj_scene,
        )

    def render(self) -> np.ndarray:
        viewport = mj.MjrRect(0, 0, self._width, self._height)
        out = np.empty((viewport.height, viewport.width, 3), dtype=np.uint8)

        assert self._mjr_context is not None, (
            "MjrContext should not be None at this stage"
        )
        mj.mjr_render(viewport, self._mj_scene, self._mjr_context)
        mj.mjr_readPixels(rgb=out, depth=None, viewport=viewport, con=self._mjr_context)

        return out

    def __del__(self) -> None:
        if hasattr(self, "_mjr_context") and self._mjr_context:
            self._mjr_context.free()
        self._mjr_context = None

def run_test(filepath: Path) -> None:
    model = mj.MjModel.from_xml_path(filepath.as_posix())
    data = mj.MjData(model)
    renderer = Renderer(model, 640, 480)

    mj.mj_resetData(model, data)

    for _ in range(10):
        mj.mj_step(model, data)
        renderer.update(data)
        _ = renderer.render()

def main() -> int:
    args = tyro.cli(Args)

    if not args.filepath.is_file():
        return 1

    for _ in tqdm(range(10)):
        run_test(args.filepath)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
