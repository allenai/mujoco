FROM quay.io/pypa/manylinux_2_28_x86_64

RUN :\
    && dnf update -y \
    && dnf install -y \
        wayland-devel mesa-libGL-devel libXinerama-devel \
        libXcursor-devel libxkbcommon-x11-devel \
        libXrandr-devel libXi-devel \
        clang llvm neovim \
        SDL2-devel \
        vulkan vulkan-tools vulkan-headers vulkan-loader-devel \
    && :

COPY . /mujoco

WORKDIR /mujoco

ENTRYPOINT [ "bash", "-l" ]

