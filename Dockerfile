FROM vllm/vllm-openai:latest

# Upgrade vllm to required version (>=0.12.0 for Nemotron-3-Nano FP8 support)
RUN pip install -U "vllm>=0.12.0"

# Bake in the custom reasoning parser — kept in /opt to avoid vllm mistaking
# the working directory for a model directory during speculator config resolution
RUN curl -fsSL -o /opt/nano_v3_reasoning_parser.py \
    https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8/resolve/main/nano_v3_reasoning_parser.py

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

EXPOSE 8000

CMD ["/opt/start.sh"]
