#!/usr/bin/env bash
# Push RunPod secrets from YOUR vault env → RunPod's secret manager, via the API.
# RUN THIS YOURSELF (it reads the live key values from your env). The agent never
# handles the values — this script does. It prints only secret NAMES + HTTP status,
# never a key value.
#
#   bash push-secrets-to-runpod.sh
#
# Needs in env: RUNPOD_API_KEY, and any of CIVITAI_API_KEY / HF_TOKEN / OPENROUTER_API_KEY
# you want stored. Already-present secrets are overwritten (idempotent).
set -u
: "${RUNPOD_API_KEY:?RUNPOD_API_KEY not set}"

push() {
  local name="$1" val="$2"
  if [ -z "$val" ]; then echo "  $name: (not in env — skipped)"; return; fi
  # Build the GraphQL body with node so the value is JSON-escaped safely and never
  # echoed. RunPod mutation: saveSecret(input:{name,value}).
  local code
  code=$(VAL="$val" NAME="$name" node -e '
    const q = `mutation{saveSecret(input:{name:${JSON.stringify(process.env.NAME)},value:${JSON.stringify(process.env.VAL)}}){name}}`;
    process.stdout.write(JSON.stringify({query:q}));
  ' | curl -s --max-time 20 -o /dev/null -w "%{http_code}" -X POST "https://api.runpod.io/graphql" \
       -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" -d @-)
  echo "  $name: HTTP $code"
}

echo "Pushing secrets to RunPod (values read from env, never printed):"
push CIVITAI_API_KEY     "${CIVITAI_API_KEY:-}"
push HF_TOKEN            "${HF_TOKEN:-}"
# OpenRouter is NOT needed by RunPod/ComfyUI (image only) — uncomment only if you really want it there:
# push OPENROUTER_API_KEY "${OPENROUTER_API_KEY:-}"

echo "Done. Verify names with: curl -s -X POST https://api.runpod.io/graphql -H \"Authorization: Bearer \$RUNPOD_API_KEY\" -H 'Content-Type: application/json' -d '{\"query\":\"query{myself{secrets{name}}}\"}'"
