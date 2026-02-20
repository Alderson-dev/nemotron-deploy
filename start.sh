#!/bin/bash
set -e

# --- HuggingFace auth ---
if [ -n "$HF_TOKEN" ]; then
    echo "Logging in to HuggingFace..."
    huggingface-cli login --token "$HF_TOKEN"
fi

# --- Model cache: use RunPod network volume if available ---
# Mount your network volume at /workspace on RunPod for persistent model caching.
# The model (~30GB) will download on first start and be reused on subsequent starts.
export HF_HOME="${HF_HOME:-/workspace/.cache/huggingface}"
mkdir -p "$HF_HOME"

# --- Configurable parameters (override via RunPod environment variables) ---
MODEL_NAME="${MODEL_NAME:-nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-model}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-8}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-1}"
PORT="${PORT:-8000}"

# Required for FP8 MoE performance
export VLLM_USE_FLASHINFER_MOE_FP8=1

# Needed if MAX_MODEL_LEN > 256k (e.g. 1M context)
if [ "${MAX_MODEL_LEN}" -gt 262144 ] 2>/dev/null; then
    export VLLM_ALLOW_LONG_MAX_MODEL_LEN=1
fi

echo "Starting vLLM server..."
echo "  Model:               $MODEL_NAME"
echo "  Served as:           $SERVED_MODEL_NAME"
echo "  Max context length:  $MAX_MODEL_LEN"
echo "  Max sequences:       $MAX_NUM_SEQS"
echo "  Tensor parallel:     $TENSOR_PARALLEL_SIZE"
echo "  Port:                $PORT"
echo "  HF cache:            $HF_HOME"


exec vllm serve "$MODEL_NAME" \
    --served-model-name "$SERVED_MODEL_NAME" \
    --max-num-seqs "$MAX_NUM_SEQS" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --max-model-len "$MAX_MODEL_LEN" \
    --port "$PORT" \
    --trust-remote-code \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder \
    --reasoning-parser-plugin /app/nano_v3_reasoning_parser.py \
    --reasoning-parser nano_v3 \
    --kv-cache-dtype fp8
