"""Test-only mock of an OpenAI-compatible endpoint. NOT part of the pattern.

Exists so dispatch.sh's plumbing (env handling, probe, auth header) can be
smoke-tested in environments that can't reach a real model server:

    python3 scripts/mock_endpoint.py &          # serves on 127.0.0.1:8080
    OPENAI_BASE_URL=http://127.0.0.1:8080/v1 OPENAI_API_KEY=test \
        RELAY_MODEL=mock scripts/dispatch.sh 0001 --probe
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authed(self):
        return self.headers.get("Authorization", "").startswith("Bearer ")

    def do_GET(self):
        if not self._authed():
            return self._send(401, {"error": "missing bearer token"})
        if self.path.rstrip("/").endswith("/models"):
            return self._send(200, {"object": "list",
                                    "data": [{"id": "mock", "object": "model"}]})
        self._send(404, {"error": "not found"})

    def do_POST(self):
        if not self._authed():
            return self._send(401, {"error": "missing bearer token"})
        self._send(200, {"id": "mock-1", "object": "chat.completion",
                         "choices": [{"index": 0, "finish_reason": "stop",
                                      "message": {"role": "assistant",
                                                  "content": "mock response"}}]})

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    print("mock endpoint on http://127.0.0.1:8080 (Ctrl-C to stop)")
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
