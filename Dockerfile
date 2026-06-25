# Custom ComfyUI serverless worker for SillyTavern-Lab: base worker + IP-Adapter FaceID.
# Built on GitHub Actions (no local Docker) -> pushed to GHCR -> pulled by RunPod Serverless.
# Models (uncensored SDXL checkpoint, IP-Adapter, ControlNet, upscaler, insightface buffalo_l)
# live on the attached RunPod NETWORK VOLUME, not baked in here.
FROM runpod/worker-comfyui:5.8.6-base

# insightface + onnxruntime-gpu are NOT pulled by the node installer (gated), so install explicitly.
RUN pip install --no-cache-dir insightface onnxruntime-gpu

# IP-Adapter custom node (FaceID / PlusV2 face-lock)
RUN comfy-node-install comfyui_ipadapter_plus
