#!/usr/bin/env bash
# Runs ON a RunPod staging pod (EUR-IS-1) with volume ehpkszdhz5 mounted at /workspace.
# Downloads the A/B checkpoint library + controlnet DIRECT to the volume, in-datacenter.
# Verifies byte sizes, writes a status file, then self-stops the pod (no idle GPU billing).
# Secrets come from pod env (CIVITAI_API_KEY, HF_TOKEN, RUNPOD_API_KEY, POD_ID) — never hardcoded.
set -uo pipefail

VOL=/workspace
CK="$VOL/models/checkpoints"
CN="$VOL/models/controlnet"
STATUS="$VOL/CHECKPOINT_STAGING.txt"
mkdir -p "$CK" "$CN"
: > "$STATUS"
log(){ echo "$(date -u +%H:%M:%S) $*" | tee -a "$STATUS"; }

log "STAGE_START $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"

# civitai: model file by versionId -> $CK/<dest>. Skip if already present at expected size.
civ(){ # ver dest expectMB
  local ver="$1" dest="$2" exp="$3" out="$CK/$2"
  if [ -f "$out" ]; then local mb=$(( $(stat -c%s "$out")/1048576 )); if [ "$mb" -ge $((exp-50)) ]; then log "SKIP $dest (${mb}MB ok)"; return; fi; fi
  log "GET  $dest (ver $ver)"
  curl -sL -H "Authorization: Bearer ${CIVITAI_API_KEY}" \
    "https://civitai.com/api/download/models/${ver}" -o "$out.part" && mv "$out.part" "$out"
  local mb=$(( $(stat -c%s "$out" 2>/dev/null||echo 0)/1048576 ))
  if [ "$mb" -ge $((exp-50)) ]; then log "OK   $dest (${mb}MB)"; else log "FAIL $dest (${mb}MB < ${exp})"; rm -f "$out"; fi
}

# HF resolve -> $CN. (controlnet union promax)
hf(){ # url dest expectMB
  local url="$1" out="$CN/$2" exp="$3"
  if [ -f "$out" ]; then local mb=$(( $(stat -c%s "$out")/1048576 )); if [ "$mb" -ge $((exp-50)) ]; then log "SKIP $2 (${mb}MB ok)"; return; fi; fi
  log "GET  $2 (HF)"
  curl -sL -H "Authorization: Bearer ${HF_TOKEN}" "$url" -o "$out.part" && mv "$out.part" "$out"
  local mb=$(( $(stat -c%s "$out" 2>/dev/null||echo 0)/1048576 ))
  if [ "$mb" -ge $((exp-50)) ]; then log "OK   $2 (${mb}MB)"; else log "FAIL $2 (${mb}MB)"; rm -f "$out"; fi
}

# --- A/B checkpoint library (uncensored SDXL, 30-step standard) ---
civ 1759168 juggernautXL_ragnarok.safetensors     6617   # forge default (was 0-byte)
civ 789646  realvisxlV50.safetensors              13233  # full V5 (non-Lightning)
civ 2514955 epicrealismXL.safetensors             6617
civ 290640  ponyDiffusionV6XL.safetensors         6617
civ 2840768 cyberrealisticXL.safetensors          13233
civ 570138  leosamsHelloworldXL.safetensors       6617
civ 3045803 lustifySDXL.safetensors               6617
civ 916744  zavychromaXL.safetensors              6617

# --- controlnet union promax (pose/depth A/B) ---
hf "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors" \
   controlnet_union_sdxl_promax.safetensors 2397

log "INVENTORY:"; ls -la "$CK" "$CN" | tee -a "$STATUS"
log "STAGE_COMPLETE"
# NOTE: no RUNPOD_API_KEY on this pod by design (no master-key on rented machines).
# The orchestrator polls $STATUS via RunPod S3 and stops this pod when STAGE_COMPLETE appears.
