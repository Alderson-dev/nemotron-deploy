FROM vllm/vllm-openai:latest

# Upgrade vllm to required version (>=0.12.0 for Nemotron-3-Nano FP8 support)
RUN pip install -U "vllm>=0.12.0"

# Parser lives in its own isolated directory so vllm's speculator config scan
# (which searches the plugin's directory for JSON configs) finds nothing else
RUN mkdir -p /opt/parsers && \
    curl -fsSL -o /opt/parsers/nano_v3_reasoning_parser.py \
    https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8/resolve/main/nano_v3_reasoning_parser.py

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8000

CMD ["/start.sh"]
