#!/usr/bin/env python3
"""GPU-free lifecycle test against the actual pinned llama-swap binary.

Usage: python test-strata-llama-swap.py /path/to/llama-swap
Backends emulate Strata's HTTP server + native child process, without weights.
"""

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ORCA = "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs"


def backend(args):
    child = subprocess.Popen(
        [
            sys.executable,
            "-c",
            "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(300)",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    Path(args.state, args.model + ".json").write_text(
        json.dumps([os.getpid(), child.pid])
    )

    def stop(_sig, _frame):
        if args.stubborn:
            while True:
                time.sleep(0.1)
        child.kill()
        child.wait()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"{}")

        def do_POST(self):
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            assert data["model"] == args.model, data
            self.send_response(200)
            self.send_header(
                "Content-Type",
                "text/event-stream" if data.get("stream") else "application/json",
            )
            self.end_headers()
            if data.get("stream"):
                self.wfile.write(
                    b'data: {"choices":[{"delta":{"content":"ok"}}]}\n\ndata: [DONE]\n\n'
                )
            else:
                self.wfile.write(
                    json.dumps(
                        {
                            "model": args.model,
                            "choices": [{"message": {"content": "ok"}}],
                        }
                    ).encode()
                )

        def log_message(self, *_args):
            pass

    # Eager startup: /health is unavailable until the mock engine is ready.
    time.sleep(0.2)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


def unused_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def alive(pid):
    # A zombie has released resources; its host parent can reap it asynchronously.
    try:
        state = Path(f"/proc/{pid}/stat").read_text().split(")", 1)[1].split()[0]
        return state != "Z"
    except FileNotFoundError:
        return False


def eventually(test, description, timeout=8):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if test():
            return
        time.sleep(0.05)
    raise AssertionError(description)


def integration(binary):
    with tempfile.TemporaryDirectory(prefix="strata-lifecycle-") as d:
        root = Path(d)
        port = unused_port()
        models = {}
        for model in ["bonsai-2-27b", "qwen3.8-27b", ORCA]:
            backend_port = unused_port()
            models[model] = {
                "cmd": f"{sys.executable} {Path(__file__).resolve()} --backend --state {d} --model {model} --port {backend_port}"
                + (" --stubborn" if model == ORCA else ""),
                "proxy": f"http://127.0.0.1:{backend_port}",
                "checkEndpoint": "/health",
                "ttl": 1 if model == ORCA else 60,
                "unloadTimeout": 1,
                "useModelName": model,
            }
        config = root / "config.json"
        config.write_text(json.dumps({"healthCheckTimeout": 15, "models": models}))
        # JSON is valid YAML. No groups: exercise the production exclusive default.
        with (root / "swap.log").open("w") as log:
            swap = subprocess.Popen(
                [binary, "--listen", f"127.0.0.1:{port}", "--config", str(config)],
                stdout=log,
                stderr=log,
            )
            base = f"http://127.0.0.1:{port}"

            def request(path, data=None):
                body = json.dumps(data).encode() if data is not None else None
                req = urllib.request.Request(
                    base + path, data=body, headers={"Content-Type": "application/json"}
                )
                with urllib.request.urlopen(req, timeout=20) as response:
                    return response.read()

            def ready():
                try:
                    return len(json.loads(request("/v1/models"))["data"]) == 3
                except (OSError, ValueError):
                    return False

            def pids(model):
                return json.loads((root / (model + ".json")).read_text())

            def ask(model, stream=False):
                body = request(
                    "/v1/chat/completions",
                    {
                        "model": model,
                        "messages": [{"role": "user", "content": "hello"}],
                        "stream": stream,
                    },
                )
                assert (
                    b"[DONE]" in body if stream else json.loads(body)["model"] == model
                )
                return pids(model)

            try:
                eventually(ready, "llama-swap did not start")
                bonsai = ask("bonsai-2-27b")
                orca = ask(ORCA, stream=True)
                assert all(not alive(pid) for pid in bonsai), (
                    "Bonsai child survived Orca load"
                )
                qwen = ask("qwen3.8-27b")
                assert all(not alive(pid) for pid in orca), (
                    "Orca server/native child survived model switch"
                )
                orca = ask(ORCA)
                assert all(not alive(pid) for pid in qwen), (
                    "Qwen child survived Orca load"
                )
                eventually(
                    lambda: all(not alive(pid) for pid in orca),
                    "Orca child survived idle TTL",
                )
                orca = ask(ORCA)
                assert orca != pids("qwen3.8-27b")
                swap.terminate()
                swap.wait(timeout=40)
                eventually(
                    lambda: all(not alive(pid) for pid in orca),
                    "Orca child survived llama-swap shutdown",
                )
                print(
                    "PASS: listing, same model ID, eager readiness, streaming, exclusive switches, forced process-tree cleanup, idle TTL, reload, shutdown"
                )
            finally:
                if swap.poll() is None:
                    swap.terminate()
                    swap.wait(timeout=40)
                for path in root.glob("*.json"):
                    if path == config:
                        continue
                    for pid in json.loads(path.read_text()):
                        if alive(pid):
                            os.kill(pid, signal.SIGKILL)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", nargs="?")
    parser.add_argument("--backend", action="store_true")
    parser.add_argument("--state")
    parser.add_argument("--model")
    parser.add_argument("--port", type=int)
    parser.add_argument("--stubborn", action="store_true")
    options = parser.parse_args()
    if options.backend:
        backend(options)
    else:
        integration(options.binary)
