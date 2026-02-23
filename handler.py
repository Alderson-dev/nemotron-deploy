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


def handler(job):
    job_input = job["input"]

    openai_route = job_input.pop("openai_route", "/v1/chat/completions")
    url = f"{VLLM_BASE_URL}{openai_route}"
    stream = job_input.get("stream", False)

    if stream:
        response = requests.post(url, json=job_input, stream=True)
        response.raise_for_status()

        for line in response.iter_lines(decode_unicode=True):
            if line.startswith("data: "):
                chunk = line[len("data: "):]
                if chunk.strip() == "[DONE]":
                    break
                yield chunk
    else:
        response = requests.post(url, json=job_input)
        response.raise_for_status()
        return response.json()


wait_for_vllm()
runpod.serverless.start({"handler": handler, "return_aggregate_stream": True})
