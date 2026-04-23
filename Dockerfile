# NVIDIA CUDA devel base — nvcc + CMake required for building C++/CUDA decoder
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

ARG DFLASH_VERSION
ARG CUDA_ARCH=86
LABEL org.opencontainers.image.title="Lucebox DFlash" \
      org.opencontainers.image.description="Speculative decoding server for Qwen 3.5-27B on RTX 3090" \
      org.opencontainers.image.source="https://github.com/Luce-Org/lucebox-hub" \
      org.opencontainers.image.version="${DFLASH_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    git \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git init \
    && git remote add origin https://github.com/Luce-Org/lucebox-hub.git \
    && git fetch --depth 1 origin ${DFLASH_VERSION} \
    && git checkout FETCH_HEAD \
    && git submodule update --init --depth 1

WORKDIR /app/dflash

RUN cmake -B build -S . \
    -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-shlib-undefined" \
    && cmake --build build --target test_dflash -j$(nproc)

RUN pip3 install --no-cache-dir \
    torch \
    --index-url https://download.pytorch.org/whl/cu128

RUN pip3 install --no-cache-dir \
    fastapi \
    uvicorn \
    transformers \
    jinja2 \
    huggingface-hub

RUN useradd -m -u 1000 lucebox && chown -R lucebox:lucebox /app
USER lucebox

VOLUME /app/dflash/models

EXPOSE 8000

CMD ["python3", "scripts/server.py", "--port", "8000"]
