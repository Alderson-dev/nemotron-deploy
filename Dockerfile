FROM vllm/vllm-openai:latest

# Upgrade vllm to required version (>=0.12.0 for Nemotron-3-Nano FP8 support)
RUN pip install -U "vllm>=0.12.0"

WORKDIR /app

# Bake in the custom reasoning parser at build time
RUN curl -fsSL -o /app/nano_v3_reasoning_parser.py \
    https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8/resolve/main/nano_v3_reasoning_parser.py

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
