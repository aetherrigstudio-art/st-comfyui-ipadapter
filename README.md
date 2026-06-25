# st-comfyui-ipadapter

Custom **ComfyUI serverless worker** image for the SillyTavern-Lab image pipeline —
the stock `runpod/worker-comfyui` base + **IP-Adapter FaceID** (face-lock) + InsightFace.

Built on **GitHub Actions** (no local Docker) and published to **GHCR**, then pulled by a
**RunPod Serverless** endpoint. Models (uncensored SDXL checkpoint, IP-Adapter, ControlNet,
upscaler) live on the attached **network volume**, not in the image.

Image: `ghcr.io/aetherrigstudio-art/st-comfyui-ipadapter:5.8.6`

Hero/full-quality renders (character portraits, seed-locked emotion sprite packs) route here;
quick/incidental in-chat images fall back to free AI Horde.
