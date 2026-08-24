#!/usr/bin/env bash
# Download the official ggml-tiny.en.bin Whisper model for local / release builds.
# The model is not committed; developers and CI place it at models/ggml-tiny.en.bin.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODEL_DIR="${ROOT}/models"
MODEL_PATH="${MODEL_DIR}/ggml-tiny.en.bin"
MODEL_URL="${WHISPER_MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin}"
MIN_BYTES=$((10 * 1024 * 1024))

file_size() {
  local path="$1"
  if stat -f%z "${path}" >/dev/null 2>&1; then
    stat -f%z "${path}"
  else
    stat -c%s "${path}"
  fi
}

human_mb() {
  local bytes="$1"
  echo "$((bytes / 1024 / 1024)) MB"
}

echo "==> Ensuring Whisper model (ggml-tiny.en.bin)"
mkdir -p "${MODEL_DIR}"

if [[ -f "${MODEL_PATH}" ]]; then
  existing_size="$(file_size "${MODEL_PATH}")"
  if (( existing_size > MIN_BYTES )); then
    echo "    Already present: ${MODEL_PATH} ($(human_mb "${existing_size}"))"
    echo "==> Model ready"
    exit 0
  fi
  echo "    Existing file is only ${existing_size} bytes (need >10MB); resuming download"
fi

echo "    Source: ${MODEL_URL}"
echo "    Destination: ${MODEL_PATH}"

# -L follows Hugging Face redirects; -C - resumes a partial file.
# --fail makes HTTP error pages a hard failure instead of a tiny "model".
curl -L --fail --retry 5 --retry-delay 2 -C - \
  -A "um-download-model/1.0 (https://github.com/r3dbars/um)" \
  -o "${MODEL_PATH}" "${MODEL_URL}"

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "error: download finished but ${MODEL_PATH} is missing" >&2
  exit 1
fi

final_size="$(file_size "${MODEL_PATH}")"
if (( final_size <= MIN_BYTES )); then
  echo "error: downloaded file is only ${final_size} bytes (expected >10MB). The download is incomplete or not the ggml model." >&2
  exit 1
fi

echo "    Downloaded $(human_mb "${final_size}") (${final_size} bytes)"
echo "==> Model ready at ${MODEL_PATH}"
