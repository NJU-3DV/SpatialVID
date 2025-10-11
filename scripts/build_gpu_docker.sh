#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$WORKDIR"

# Default parallel jobs; can be overridden by CLI --num-jobs or env NUM_JOBS
NUM_JOBS=${NUM_JOBS:-8}

# Simple CLI: support --num-jobs or -j
while [ $# -gt 0 ]; do
  case "$1" in
    --num-jobs|-j)
      if [ $# -lt 2 ]; then
        echo "Missing value for $1" >&2; exit 1
      fi
      NUM_JOBS="$2"; shift 2;;
    --help|-h)
      echo "Usage: $0 [--num-jobs N] [--gpu]"; exit 0;;
    --gpu)
      BUILD_WITH_GPU=1; shift;;
    *)
      # unknown; stop parsing
      break;;
  esac
done

echo "Using NUM_JOBS=${NUM_JOBS}"

echo "[1/6] Checking docker availability..."
if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Please install Docker and (for GPU) NVIDIA Container Toolkit." >&2
  exit 2
fi

# Quick permission check: can we talk to the docker daemon?
if ! docker info >/dev/null 2>&1; then
  echo ""
  echo "ERROR: cannot connect to the Docker daemon. Permission denied or daemon not running."
  echo "Common fixes (pick one):"
  echo "  1) Run the script with sudo (quick, but files may be created as root):"
  echo "       sudo ./scripts/build_gpu_docker.sh"
  echo "  2) Add your user to the 'docker' group and re-login (recommended):"
  echo "       sudo usermod -aG docker \$USER" ; 
  echo "       # then log out and log back in, or run: newgrp docker"
  echo "  3) If Docker is installed as snap, use sudo or follow snap-specific docs."
  echo "  4) Ensure daemon is running: sudo systemctl start docker" 
  echo ""
  exit 3
fi

echo "[2/6] Checking NVIDIA runtime support via a test container (this may fail if no GPU or toolkit)..."
if docker run --rm --gpus all nvidia/cuda:12.1-runtime-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA runtime is available. Will build with GPU support.";
else
  echo "Warning: NVIDIA runtime test failed. Build may still succeed, but runtime NVENC/NNDEC features won't work on this host.";
fi

IMAGE_TAG="spatialvid-gpu:latest"

echo "[3/6] Building GPU image with Dockerfile (this may take a long time)..."
# Pre-pull base images used by Dockerfile to fail early on network/auth issues
BUILDER_IMAGE="swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04" # cuda:12.1.0-cudnn8-devel-ubuntu22.04
RUNTIME_IMAGE="swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nvidia/cuda:12.6.3-runtime-ubuntu22.04" # cuda:12.1.1-cudnn8-runtime-ubuntu22.04
# BUILDER_IMAGE="cuda:12.1.0-cudnn8-devel-ubuntu22.04"
# RUNTIME_IMAGE="cuda:12.1.1-cudnn8-runtime-ubuntu22.04"

echo "Pre-pulling base images to validate network/auth and warm cache:"
retry_pull() {
  local img="$1"
  local i
  for i in 1 2 3; do
    echo "  pull attempt $i for ${img}..."
    if docker pull "${img}"; then
      echo "  pulled ${img}"
      return 0
    fi
    sleep $((i * 2))
  done
  echo "Failed to pull ${img} after retries" >&2
  return 1
}

echo "- builder: ${BUILDER_IMAGE}"
echo "- runtime: ${RUNTIME_IMAGE}"
retry_pull "${BUILDER_IMAGE}" || true
retry_pull "${RUNTIME_IMAGE}" || true

USE_BUILDX_CACHE=${USE_BUILDX_CACHE:-1}
BUILD_WITH_GPU=${BUILD_WITH_GPU:-0}
# Extra build args for GPU-enabled builds (passed to docker/buildx)
BUILD_GPU_ARGS=""
if [ "${BUILD_WITH_GPU}" = "1" ] || [ "${BUILD_WITH_GPU}" = "true" ]; then
  echo "GPU build requested: will pass NVIDIA build args to docker build/buildx"
  BUILD_GPU_ARGS="--build-arg=NVIDIA_VISIBLE_DEVICES=all --build-arg=NVIDIA_DRIVER_CAPABILITIES=compute,utility"
fi
# Prefer buildx/BuildKit if available for better output; otherwise fall back
if docker buildx version >/dev/null 2>&1; then
  echo "docker buildx detected — using BuildKit for build"
  # Optional: allow overriding the BuildKit image used by the docker-container driver
  # BUILDKIT_IMAGE="${BUILDKIT_IMAGE:-moby/buildkit:buildx-stable-1}" # moby/buildkit:buildx-stable-1
  BUILDKIT_IMAGE="${BUILDKIT_IMAGE:-swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/moby/buildkit:buildx-stable-1}" # moby/buildkit:buildx-stable-1

  # If cache is requested, try to create/use a docker-container builder that can
  # use a custom BuildKit image (useful when Docker Hub is blocked and you have a private mirror).
  if [ "${USE_BUILDX_CACHE}" -eq 1 ]; then
    echo "Using buildx local cache at ./.buildx-cache"
    echo "Ensuring BuildKit image is available: ${BUILDKIT_IMAGE}"
    retry_pull "${BUILDKIT_IMAGE}" || echo "Warning: could not pre-pull ${BUILDKIT_IMAGE}; builder creation may still attempt to pull it"

    # Some buildx/bootstrap paths will try to pull the canonical image name
    # 'moby/buildkit:buildx-stable-1'. To avoid touching Docker Hub, tag the
    # pulled private mirror image to that canonical name locally so the daemon
    # can find it without external access.
    CANONICAL_BUILDKIT_TAG="moby/buildkit:buildx-stable-1"
    if docker image inspect "${BUILDKIT_IMAGE}" >/dev/null 2>&1; then
      echo "Tagging ${BUILDKIT_IMAGE} -> ${CANONICAL_BUILDKIT_TAG} (local only)"
      docker tag "${BUILDKIT_IMAGE}" "${CANONICAL_BUILDKIT_TAG}" || true
    fi

    # Create a named builder that runs as a container (supports cache export/import).
    # If a builder with this name already exists, remove and recreate it so the
    # desired BUILDKIT_IMAGE is used. Reusing an old builder can cause the
    # daemon to pull the original moby/buildkit image (from Docker Hub) during
    # bootstrap which fails in restricted networks.
    if docker buildx inspect spatialvid-builder >/dev/null 2>&1; then
      echo "Existing buildx builder 'spatialvid-builder' found — removing to ensure it uses ${BUILDKIT_IMAGE}"
      if ! docker buildx rm spatialvid-builder >/dev/null 2>&1; then
        echo "Warning: could not remove existing 'spatialvid-builder'. It may be in use by another process. Attempting to recreate anyway."
      fi
    fi

    echo "Creating docker-container buildx builder 'spatialvid-builder' using BuildKit image ${BUILDKIT_IMAGE}"
    if ! docker buildx create --name spatialvid-builder --driver docker-container --use --driver-opt image="${BUILDKIT_IMAGE}"; then
      echo "Warning: failed to create docker-container builder with custom BuildKit image; will fall back to default buildx behavior (may fail to export cache)"
    fi

    # If we successfully have the named builder, instruct buildx to use it. Otherwise omit --builder.
    BUILDX_BUILDER_ARG=""
    if docker buildx inspect spatialvid-builder >/dev/null 2>&1; then
      BUILDX_BUILDER_ARG="--builder spatialvid-builder"
    fi

    DOCKER_BUILDKIT=1 docker buildx build ${BUILDX_BUILDER_ARG} --load --progress=plain \
      --cache-to type=local,dest=.buildx-cache --cache-from type=local,src=.buildx-cache \
      ${BUILD_GPU_ARGS} --build-arg NUM_JOBS=${NUM_JOBS} -f Dockerfile -t ${IMAGE_TAG} .
  else
  DOCKER_BUILDKIT=1 docker build --progress=plain ${BUILD_GPU_ARGS} --build-arg NUM_JOBS=${NUM_JOBS} -f Dockerfile -t ${IMAGE_TAG} .
  fi
else
  echo "docker buildx not detected — falling back to classic docker build"
  docker build ${BUILD_GPU_ARGS} --build-arg NUM_JOBS=${NUM_JOBS} -f Dockerfile -t ${IMAGE_TAG} .
fi

echo "[4/6] Checking ffmpeg version inside built image"
docker run --rm --gpus all ${IMAGE_TAG} ffmpeg -version | sed -n '1,12p' || true

echo "[5/6] Checking for vmaf filter and nvenc encoders"
docker run --rm --gpus all ${IMAGE_TAG} ffmpeg -filters | grep vmaf || echo "vmaf filter not present"
docker run --rm --gpus all ${IMAGE_TAG} ffmpeg -encoders | grep nvenc || echo "nvenc encoders not present"

echo "[6/6] Python smoke test: check python and torch (if installed)"
docker run --rm --gpus all ${IMAGE_TAG} python -c "import sys; print('python', sys.version)" || true
docker run --rm --gpus all ${IMAGE_TAG} python -c "import importlib, sys
try:
    t=importlib.import_module('torch')
    print('torch', t.__version__, 'cuda', getattr(t, 'version', None) and getattr(t.version, 'cuda', lambda: 'unknown')())
except Exception as e:
    print('torch not importable:', e)
" || true

echo "Done. If any step printed warnings or errors, inspect build output above and adjust Dockerfile (e.g., NV_CODEC_HEADERS_BRANCH, missing -dev packages)."

echo "Helpful next commands:"
echo "  docker images | grep spatialvid"
echo "  docker run --gpus all -it --rm -v \\$(pwd):/workspace -w /workspace ${IMAGE_TAG} bash"
