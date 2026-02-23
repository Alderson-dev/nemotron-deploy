FROM vllm/vllm-openai:v0.12.0

RUN mkdir -p /opt/parsers && \
    curl -fsSL -o /opt/parsers/nano_v3_reasoning_parser.py \
    https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8/resolve/main/nano_v3_reasoning_parser.py

RUN pip install httpx

COPY handler.py /handler.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8000

# Override the base image ENTRYPOINT ("vllm serve") with our own startup script.
# Without this, CMD ["/start.sh"] would be passed as the MODEL argument to vllm,
# causing vllm to try loading start.sh as a model config.
ENTRYPOINT ["/start.sh"]
