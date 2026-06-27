#!/usr/bin/env bash
# Stage all ComfyUI models onto the RunPod network volume (st-comfyui-models).
#
# RUN THIS ON A TEMPORARY RUNPOD POD that mounts the network volume at
# /runpod-volume (any cheap CPU/GPU pod). Then DELETE the pod — the serverless
# endpoint reads the same volume. Models persist; they are not baked into the image.
#
# Secrets are read from the environment — pass them when launching the pod, never
# hardcode. insightface buffalo_l is NOT staged here: it auto-downloads on first
# render (~300 MB to /root/.insightface inside the container).
#
#   CIVITAI_API_KEY=...  HF_TOKEN=...  bash stage-models.sh
set -euo pipefail

: "${CIVITAI_API_KEY:?set CIVITAI_API_KEY (civitai.com/user/account)}"
VOL=/runpod-volume/models
mkdir -p "$VOL"/{checkpoints,loras,ipadapter,controlnet,upscale_models,clip_vision}

# Skip a file that already exists and is non-trivial in size (idempotent re-runs).
have() { [ -f "$1" ] && [ "$(stat -c%s "$1" 2>/dev/null || echo 0)" -gt 1000000 ]; }
get()  { # get <url> <out> [auth-header]
  if have "$2"; then echo "✓ exists: $2"; return; fi
  echo "↓ $2"
  if [ -n "${3:-}" ]; then wget -q --show-progress --header "$3" -O "$2" "$1"
  else                      wget -q --show-progress              -O "$2" "$1"; fi
}

# 1) Primary checkpoint — Juggernaut XL Ragnarok (~6.62 GB, CivitAI, auth required)
get "https://civitai.com/api/download/models/1759168?fileId=1659952" \
    "$VOL/checkpoints/juggernautXL_ragnarok.safetensors" \
    "Authorization: Bearer $CIVITAI_API_KEY"

# 2) IP-Adapter FaceID PlusV2 SDXL (~1.49 GB) + its LoRA (~372 MB) — HF, no auth
get "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin" \
    "$VOL/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin"
get "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
    "$VOL/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"

# 3) CLIP Vision (required by IP-Adapter; ~1.71 GB) — HF
get "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "$VOL/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"

# 4) ControlNet Union SDXL promax (~1.4 GB) — HF
get "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.fp16.safetensors" \
    "$VOL/controlnet/controlnet_union_sdxl_promax.safetensors"

# 5) Upscalers — 4x-UltraSharp (~67 MB) + RealESRGAN fallback
get "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth" \
    "$VOL/upscale_models/4x-UltraSharp.pth"
get "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
    "$VOL/upscale_models/RealESRGAN_x4plus.pth"

echo ""
echo "=== staged model tree ==="
find "$VOL" -type f -printf '%10s  %p\n' 2>/dev/null | sort -k2
echo ""
# Fail loudly if the critical checkpoint is missing/short — the render can't run without it.
CK="$VOL/checkpoints/juggernautXL_ragnarok.safetensors"
if have "$CK"; then echo "✓ checkpoint present — staging OK. Delete this pod; the serverless endpoint will use the volume."
else echo "✗ checkpoint MISSING/short — check CIVITAI_API_KEY and the CivitAI download URL."; exit 1; fi
