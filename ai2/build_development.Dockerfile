FROM nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND="noninteractive"
ENV TZ="America/Los_Angeles"

RUN :\
    && apt-get update \
    && apt-get install -y \
        build-essential pkg-config curl git wget cmake unzip ninja-build python3-dev \
        man-db manpages manpages-dev manpages-posix manpages-posix-dev \
        libgl1-mesa-dev libwayland-dev libxinerama-dev libxkbcommon-dev libxrandr-dev libxi-dev libxcursor-dev \
    && rm -rf /var/lib/apt/lists/* \
    && :

# Install Vulkan SDK
ARG VULKAN_SDK_VERSION="1.4.313"
RUN :\
    && echo "Install Vulkan-SDK ${VULKAN_SDK_VERSION}" \
    && wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-${VULKAN_SDK_VERSION}-noble.list https://packages.lunarg.com/vulkan/${VULKAN_SDK_VERSION}/lunarg-vulkan-${VULKAN_SDK_VERSION}-noble.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends vulkan-sdk \
    && rm -rf /var/lib/apt/lists/* \
    && :

ENV PATH="/root/.local/bin/:$PATH"
ENV PYTHONBREAKPOINT="ipdb.set_trace"

ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh

RUN uv venv /root/.venv --python 3.11
ENV VIRTUAL_ENV=/root/.venv
ENV PATH="/root/.venv/bin:$PATH"

WORKDIR /mujoco

ENTRYPOINT [ "bash", "-l" ]
