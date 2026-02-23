import runpod
import requests
import time

VLLM_BASE_URL = "http://localhost:8000"


def wait_for_vllm(timeout=600, interval=5):
    """Block until the local vLLM server is healthy."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(f"{VLLM_BASE_URL}/health", timeout=5)
            if r.status_code == 200:
                print("vLLM server is ready.")
                return
        except requests.ConnectionError:
            pass
        print(f"Waiting for vLLM server... ({int(time.time() - start)}s)")
        time.sleep(interval)
    raise TimeoutError("vLLM server did not become healthy in time.")


def _post_to_vllm(job_input):
    """Extract route and forward request to vLLM. Returns (url, response)."""
    openai_route = job_input.pop("openai_route", "/v1/chat/completions")
    url = f"{VLLM_BASE_URL}{openai_route}"
    stream = job_input.get("stream", False)
    response = requests.post(url, json=job_input, stream=stream)
    if not response.ok:
        raise RuntimeError(f"vLLM {response.status_code}: {response.text}")
    return response


def handler(job):
    job_input = job["input"]
    response = _post_to_vllm(job_input)
    return response.json()


def generator_handler(job):
    job_input = job["input"]
    response = _post_to_vllm(job_input)
    for line in response.iter_lines(decode_unicode=True):
        if line.startswith("data: "):
            chunk = line[len("data: "):]
            if chunk.strip() == "[DONE]":
                break
            yield chunk


def dynamic_handler(job):
    """Route to generator or regular handler based on stream flag."""
    if job["input"].get("stream", False):
        return generator_handler(job)
    return handler(job)


wait_for_vllm()
runpod.serverless.start({"handler": dynamic_handler, "return_aggregate_stream": True})
