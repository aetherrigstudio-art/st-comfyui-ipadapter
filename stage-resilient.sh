#!/usr/bin/env bash
# Resilient model staging for a RunPod pod — runs ON the pod, mounts /runpod-volume.
# Independent downloads (one bad URL won't kill the pod), per-file result + size
# logged to /runpod-volume/STAGING_STATUS.txt, then stays alive so the status file
# can be read. Designed for the no-container-log RunPod case: the VOLUME is the log.
#
# Secrets come from pod ENV (set via RunPod Secrets references in the pod spec):
#   CIVITAI_API_KEY (optional — only the CivitAI checkpoints need it)
# HF downloads are public (no auth required); HF_TOKEN used only if present.
set -u
VOL=/runpod-volume/models
LOG=/runpod-volume/STAGING_STATUS.txt
mkdir -p "$VOL"/{checkpoints,loras,ipadapter,controlnet,upscale_models,clip_vision}
: > "$LOG"
log(){ echo "$(date -u +%H:%M:%S) $*" | tee -a "$LOG"; }

# get <out> <url> [auth-header] — independent, never aborts the script.
get(){
  local out="$1" url="$2" auth="${3:-}"
  if [ -f "$out" ] && [ "$(stat -c%s "$out" 2>/dev/null || echo 0)" -gt 1000000 ]; then
    log "SKIP (exists) $(basename "$out")"; return 0
  fi
  log "GET  $(basename "$out")"
  if [ -n "$auth" ]; then wget -q --header "$auth" -O "$out" "$url"; else wget -q -O "$out" "$url"; fi
  if [ -f "$out" ] && [ "$(stat -c%s "$out" 2>/dev/null || echo 0)" -gt 1000000 ]; then
    log "OK   $(basename "$out") $(du -h "$out" | cut -f1)"
  else
    log "FAIL $(basename "$out")"; rm -f "$out"
  fi
}

log "STAGING_START region=$(cat /etc/hostname 2>/dev/null)"

# Default checkpoint — HuggingFace public Juggernaut XL v9 (no auth).
get "$VOL/checkpoints/juggernautXL_v9.safetensors" \
    "https://huggingface.co/RunDiffusion/Juggernaut-XL-v9/resolve/main/Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors"

# IP-Adapter FaceID stack (HF public)
get "$VOL/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
get "$VOL/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
get "$VOL/clip_vision/CLIP-ViT-H-14.safetensors" \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"

# ControlNet union + upscaler (HF public)
get "$VOL/controlnet/controlnet_union_sdxl_promax.safetensors" \
    "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.fp16.safetensors"
get "$VOL/upscale_models/4x-UltraSharp.pth" \
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth"

# CivitAI library extras — only if the key is present (Pony / RealVisXL / epiCRealism).
if [ -n "${CIVITAI_API_KEY:-}" ]; then
  AUTH="Authorization: Bearer $CIVITAI_API_KEY"
  get "$VOL/checkpoints/ponyDiffusionV6XL.safetensors" "https://civitai.com/api/download/models/290640?fileId=228616" "$AUTH"
  get "$VOL/checkpoints/realvisxlV50.safetensors"      "https://civitai.com/api/download/models/798204?fileId=711904" "$AUTH"
  get "$VOL/checkpoints/epicrealismXL.safetensors"     "https://civitai.com/api/download/models/2514955?fileId=2402914" "$AUTH"
else
  log "SKIP CivitAI extras (no CIVITAI_API_KEY in env)"
fi

log "STAGING_COMPLETE"
echo "--- tree ---" | tee -a "$LOG"
find "$VOL" -type f -printf '%10s  %p\n' 2>/dev/null | sort -k2 | tee -a "$LOG"
# Stay alive so the status file remains readable.
sleep 14400
