# Custom ComfyUI serverless worker for SillyTavern-Lab: base worker + IP-Adapter FaceID.
# Built on GitHub Actions (no local Docker) -> pushed to GHCR -> pulled by RunPod Serverless.
# Models (uncensored SDXL checkpoint, IP-Adapter, ControlNet, upscaler, insightface buffalo_l)
# live on the attached RunPod NETWORK VOLUME, not baked in here.
FROM runpod/worker-comfyui:5.8.6-base

# OS-level libs required by insightface/OpenCV (the FaceAnalysis provider). Without
# these the worker crashes on boot with ImportError (libGL.so.1) the moment IP-Adapter
# FaceID loads, never registers ready, and jobs hang forever in IN_QUEUE.
# Base is Ubuntu 24.04: the old `libgl1-mesa-glx` is gone — use `libgl1` + `libglx-mesa0`.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglx-mesa0 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# insightface + onnxruntime-gpu are NOT pulled by the node installer (gated), so install explicitly.
RUN pip install --no-cache-dir insightface onnxruntime-gpu

# IP-Adapter custom node (FaceID / PlusV2 face-lock)
RUN comfy-node-install comfyui_ipadapter_plus
