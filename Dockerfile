# GPU-enabled Dockerfile for SpatialVID
# Builds libvmaf and FFmpeg with NVIDIA acceleration (NVENC/NVDEC) and libvmaf_cuda
# WARNING: This is a large build and must run on a host with NVIDIA drivers and CUDA installed.

ARG UBUNTU_VERSION=22.04
ARG CUDA_BASE_IMAGE=swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04
ARG RUN_TIME_IMG=swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nvidia/cuda:12.6.3-runtime-ubuntu22.04

# ARG CUDA_BASE_IMAGE=docker.io/nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04
# ARG RUN_TIME_IMG=docker.io/nvidia/cuda:12.6.3-runtime-ubuntu22.04
FROM ${CUDA_BASE_IMAGE} as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

## Prepare apt (transport, certs, gnupg) and enable universe/multiverse
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends apt-transport-https ca-certificates gnupg dirmngr software-properties-common curl lsb-release; \
    # enable universe/multiverse which may contain codec dev packages
    add-apt-repository -y universe || true; \
    add-apt-repository -y multiverse || true; \
    rm -rf /var/lib/apt/lists/*;

## Ensure pip tools (pip installed via apt)
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel || true

## Install build tools and dependencies (with retries and fix-missing for transient network issues)
RUN set -eux; \
    export APT_OPTS="-o Acquire::Retries=3 -o Acquire::http::Timeout=30"; \
    apt-get update; \
    # show candidate versions for debugging if install fails
    apt-cache policy libx264-dev libx265-dev libvpx-dev libfdk-aac-dev || true; \
    # install packages, allow partial success and retry missing if necessary
    apt-get $APT_OPTS install -y --no-install-recommends \
        build-essential yasm nasm cmake libtool libc6-dev unzip wget git pkg-config \
        python3 python3-pip python3-venv ninja nasm ca-certificates libnuma-dev \
        libx264-dev libx265-dev libvpx-dev libfdk-aac-dev libmp3lame-dev libopus-dev \
        libass-dev libfreetype6-dev libfribidi-dev libfontconfig1-dev libopenjp2-7-dev \
        liblzma-dev libsnappy-dev zlib1g-dev libssl-dev libavdevice-dev libavfilter-dev \
        libavformat-dev libavcodec-dev pkg-config || (apt-get --fix-missing -y install && true); \
    rm -rf /var/lib/apt/lists/*;


WORKDIR /workspace/build

# Ensure git is available (in case previous apt step failed); keep this small and retry-friendly
RUN set -eux; \
    apt-get update || true; \
    apt-get install -y --no-install-recommends git ca-certificates || true; \
    rm -rf /var/lib/apt/lists/* || true;
# Ensure Meson and Ninja are available (Meson via pip for a newer/consistent version)
RUN set -eux; \
    apt-get update; \
    # install pip and ninja-build (ninja binary) so we can reliably run meson and ninja
    apt-get install -y --no-install-recommends ninja-build python3-pip python3-setuptools nasm; \
    # upgrade pip tools and install meson via python -m pip to avoid relying on 'python3 -m pip' binary name
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel; \
    python3 -m pip install --no-cache-dir 'meson==1.9.1'; \
    apt install meson -y; \
    /usr/local/bin/meson --version; \
    # meson --version; \
    ninja --version;
    # rm -rf /var/lib/apt/lists/*
    
# nv-codec-headers (NVIDIA Video Codec SDK headers) - choose branch matching CUDA
ARG NV_CODEC_HEADERS_BRANCH=sdk/12.1
RUN set -eux; \
        # Use shallow clone to reduce download time and size; fallback to full clone if branch not available
        git clone https://githubfast.com/FFmpeg/nv-codec-headers.git /workspace/build/nv-codec-headers; \
        cd /workspace/build/nv-codec-headers && git checkout "${NV_CODEC_HEADERS_BRANCH}"; \
        cd /workspace/build/nv-codec-headers && make install

# Build libvmaf with CUDA support (split into steps so failures are clearer)
RUN set -eux; \
    git clone https://githubfast.com/Netflix/vmaf.git /workspace/build/vmaf; \
    cd /workspace/build/vmaf; \
    /usr/local/bin/meson setup libvmaf/build libvmaf \
    --buildtype=release \
    -Denable_cuda=true \
    -Dcuda_include_dir=/usr/local/cuda/include \
    -Dcuda_lib_dir=/usr/local/cuda/lib64 \
    -Dcuda_compiler=/usr/local/cuda/bin/nvcc; \
    ninja -C libvmaf/build; \
    ninja -C libvmaf/build install; \
    ldconfig

# Build FFmpeg with nvenc/npp and libvmaf
ARG FFMPEG_TAG=release/6.1
ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/local/include/libvmaf
RUN set -eux; \
        # ensure runtime build deps that may be missing are installed (pkg-config, libass)
        apt-get update || true; \
        # Install pkg-config and common codec -dev packages required by FFmpeg configure
        apt-get install -y --no-install-recommends pkg-config libass-dev libfdk-aac-dev libx264-dev libx265-dev libvpx-dev libmp3lame-dev libopus-dev libopenjp2-7-dev libssl-dev gobjc || true; \
        # debug: print pkg-config info for key libs
        # pkg-config --modversion libass || true; \
        # pkg-config --modversion libfdk-aac 2>/dev/null || pkg-config --modversion libfdk_aac 2>/dev/null || true; \
        git clone https://githubfast.com/FFmpeg/FFmpeg.git /workspace/build/FFmpeg; \
        cd /workspace/build/FFmpeg; \
        git checkout ${FFMPEG_TAG}; \
        # pkg-config --modversion libvmafng || true; \
        ./configure \
         --enable-nonfree \
         --enable-cuda-nvcc \
         --enable-libnpp \
         --extra-cflags="-I/usr/local/cuda/include -I/usr/local/cuda/include -I/usr/local/include" \
         --extra-ldflags="-L/usr/local/cuda/lib64 -L/usr/local/cuda/compat" \
         --disable-static \
         --enable-shared \
         --enable-libvmaf; \
        # ./configure --enable-nonfree --enable-cuda-nvcc --enable-libnpp \
        # --extra-cflags="-I/usr/local/cuda/include -I/usr/local/cuda/include -I/usr/local/include" \
        # --extra-ldflags="-L/usr/local/cuda/lib64 -L/usr/local/cuda/compat" \
        # --disable-static --enable-shared --enable-libvmaf; \
        make -j$(nproc); \
        make install; \
        ldconfig

# Create a smaller runtime image
FROM ${RUN_TIME_IMG} as runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates python3 python3-pip python3-venv ffmpeg libnuma-dev libsm6 libxext6 libxrender1 libgl1 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy FFmpeg and libvmaf from builder (installed under /usr/local)
COPY --from=builder /usr/local /usr/local
# copy libraries installed by the builder stage if present
COPY --from=builder /usr/lib/ /usr/lib/

# Link python
RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Copy repository
COPY . /workspace

# Install Python requirements (may still fail for some packages requiring system libs)
RUN python3 -m pip --no-cache-dir install -r requirements/requirements.txt
RUN python3 -m pip --no-cache-dir install -r requirements/requirements_scoring.txt || true
RUN python3 -m pip --no-cache-dir install -r requirements/requirements_annotation.txt || true

# Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV FFMPEG_PATH=/usr/local/bin/ffmpeg
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash", "ldconfig"]
