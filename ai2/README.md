

## Manylinux builder image

```bash
# Run from the root of the repo
docker buildx build -t mujoco-ai2-manylinux:latest -f ai2/build_manylinux.Dockerfile . --platform linux/amd64
```

```bash
# Run the container
docker run -it --rm -v $PWD/python/dist/:/mujoco/python/dist/ mujoco-ai2-manylinux:latest
```

```bash
# From within the container
./build_manylinux_wheel.sh --filament --vulkan --studio --njobs 5
```

