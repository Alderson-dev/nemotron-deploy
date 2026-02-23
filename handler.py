"""
Reverse proxy for RunPod load-balancing endpoints.

Adds the /ping health-check that RunPod requires and forwards every other
request (including SSE streams) straight through to the local vLLM server.
"""

import os
import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse
import uvicorn

VLLM_URL = "http://localhost:8000"

app = FastAPI()


@app.get("/ping")
async def ping():
    """RunPod health probe — 200 when ready, 204 while initializing."""
    try:
        async with httpx.AsyncClient() as client:
            r = await client.get(f"{VLLM_URL}/health", timeout=5)
            if r.status_code == 200:
                return {"status": "healthy"}
    except (httpx.ConnectError, httpx.ReadTimeout):
        pass
    return JSONResponse({"status": "initializing"}, status_code=204)


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy(request: Request, path: str):
    """Forward every other request to vLLM."""
    url = f"{VLLM_URL}/{path}"
    headers = {k: v for k, v in request.headers.items() if k.lower() != "host"}
    body = await request.body()

    client = httpx.AsyncClient()
    vllm_request = client.build_request(
        method=request.method,
        url=url,
        headers=headers,
        content=body,
        params=request.query_params,
    )
    vllm_response = await client.send(vllm_request, stream=True)

    content_type = vllm_response.headers.get("content-type", "")

    if "text/event-stream" in content_type:
        async def stream():
            try:
                async for chunk in vllm_response.aiter_bytes():
                    yield chunk
            finally:
                await vllm_response.aclose()
                await client.aclose()

        return StreamingResponse(
            stream(),
            status_code=vllm_response.status_code,
            media_type="text/event-stream",
        )

    content = await vllm_response.aread()
    await vllm_response.aclose()
    await client.aclose()
    return Response(
        content=content,
        status_code=vllm_response.status_code,
        media_type=content_type or "application/json",
    )


if __name__ == "__main__":
    port = int(os.getenv("PROXY_PORT", "80"))
    uvicorn.run(app, host="0.0.0.0", port=port)
