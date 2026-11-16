#!/usr/bin/env python3
"""OpenAI-compatible HTTP front end for llama.cpp's DiffusionGemma engine.

`llama-diffusion-gemma-visual-server` (ggml-org/llama.cpp#24423) keeps the GGUF
resident and runs the entropy-bound block-diffusion decoder, but only speaks a
line protocol on stdin/stdout. This wraps one engine process and serves
/health, /v1/models and /v1/chat/completions so llama-swap can manage it like
any other model.

The engine commits one 256-token canvas at a time, so a stream carries one
chunk per block rather than per token. Text only: the engine loads no vision
projector. Requests run one at a time.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

QUOTE = '<|"|>'
THOUGHT_OPEN = "<|channel>"
THOUGHT_CLOSE = "<channel|>"
CALL_OPEN = "<|tool_call>"
CALL_CLOSE = "<tool_call|>"
TURN_END = ("<turn|>", "<|tool_response>")
# The engine prints DONE after these errors; any other error ends the request.
ERRORS_BEFORE_DONE = ("toolong", "gen")


def _skip_space(text: str, i: int) -> int:
    while text[i].isspace():
        i += 1
    return i


def _parse_value(text: str, i: int) -> tuple[Any, int]:
    """Parse one Gemma tool-call value: <|"|>string<|"|>, {..}, [..] or a bare scalar."""
    i = _skip_space(text, i)
    if text.startswith(QUOTE, i):
        end = text.index(QUOTE, i + len(QUOTE))
        return text[i + len(QUOTE) : end], end + len(QUOTE)
    if text[i] == "{":
        return _parse_object(text, i)
    if text[i] == "[":
        items: list[Any] = []
        i = _skip_space(text, i + 1)
        while text[i] != "]":
            item, i = _parse_value(text, i)
            items.append(item)
            i = _skip_space(text, i)
            if text[i] == ",":
                i = _skip_space(text, i + 1)
        return items, i + 1
    end = i
    while text[end] not in ",}]":
        end += 1
    raw = text[i:end].strip()
    try:
        return json.loads(raw), end
    except ValueError:
        return raw, end


def _parse_object(text: str, i: int) -> tuple[dict[str, Any], int]:
    """Parse {key:value,...} starting at text[i] == "{"; keys may be bare or quoted."""
    result: dict[str, Any] = {}
    i = _skip_space(text, i + 1)
    while text[i] != "}":
        if text.startswith(QUOTE, i):
            key, i = _parse_value(text, i)
            i = text.index(":", i)
        else:
            colon = text.index(":", i)
            key, i = text[i:colon].strip(), colon
        result[str(key)], i = _parse_value(text, i + 1)
        i = _skip_space(text, i)
        if text[i] == ",":
            i = _skip_space(text, i + 1)
    return result, i + 1


def parse_tool_call(raw: str) -> dict[str, Any] | None:
    """Convert `call:name{args}<tool_call|>` to an OpenAI tool call; None if malformed."""
    body, closed, _ = raw.partition(CALL_CLOSE)
    name, brace, _ = body.removeprefix("call:").partition("{")
    if not closed or not brace or not body.startswith("call:"):
        return None
    try:
        arguments, _ = _parse_object(body, body.index("{"))
    except (ValueError, IndexError):
        return None
    return {
        "id": f"call_{uuid.uuid4().hex[:24]}",
        "type": "function",
        "function": {"name": name.strip(), "arguments": json.dumps(arguments)},
    }


@dataclass
class Parsed:
    reasoning: str = ""
    content: str = ""
    tool_calls: list[dict[str, Any]] = field(default_factory=list)


def parse_output(text: str, open_thought: bool, final: bool) -> Parsed:
    """Split engine text (special tokens kept) into reasoning, answer and tool calls.

    `open_thought` means the prompt already opened the thought channel. Until
    `final`, an unfinished tool call is held back instead of leaking as text;
    reasoning and content only ever grow, so callers can stream the difference.
    """
    for marker in TURN_END:
        text = text.split(marker, 1)[0]
    reasoning = ""
    if text.startswith(THOUGHT_OPEN):
        open_thought, text = True, text[len(THOUGHT_OPEN) :]
    if open_thought:
        reasoning, _, text = text.partition(THOUGHT_CLOSE)
        reasoning = reasoning.removeprefix("thought\n")
    content, *calls = text.split(CALL_OPEN)
    parsed = Parsed(reasoning.strip(), content.strip())
    for raw in calls:
        call = parse_tool_call(raw)
        if call:
            parsed.tool_calls.append(call)
        elif final:
            parsed.content += CALL_OPEN + raw
    if not final:
        parsed.tool_calls = []
    return parsed


def wants_thinking(body: dict[str, Any], default: bool) -> bool:
    """Decide whether this request thinks: explicit template kwarg, then effort, then default."""
    kwargs = body.get("chat_template_kwargs")
    if isinstance(kwargs, dict) and isinstance(kwargs.get("enable_thinking"), bool):
        return kwargs["enable_thinking"]
    effort = body.get("reasoning_effort")
    if isinstance(effort, str):
        return effort != "none"
    return default


def normalize_messages(messages: Any) -> list[dict[str, Any]]:
    """Flatten text content parts to strings; reject anything that is not text."""
    if not isinstance(messages, list) or not messages:
        raise ValueError("messages must be a non-empty array")
    result: list[dict[str, Any]] = []
    for message in messages:
        if not isinstance(message, dict):
            raise ValueError("each message must be an object")
        content = message.get("content")
        if isinstance(content, list):
            if any(not isinstance(p, dict) or p.get("type") != "text" for p in content):
                raise ValueError(
                    "this endpoint is text only: remove image, audio and video parts"
                )
            message = {
                **message,
                "content": "".join(str(p.get("text", "")) for p in content),
            }
        result.append(message)
    return result


@dataclass
class Result:
    stats: dict[str, str] = field(default_factory=dict)
    error: str | None = None


@dataclass
class StreamState:
    text: str = ""  # cumulative engine text
    open: bool = False  # response headers sent
    gone: bool = False  # client disconnected


class Engine:
    """One resident engine process; requests are serialized."""

    def __init__(self, command: list[str], env: dict[str, str]) -> None:
        self.proc = subprocess.Popen(
            command,
            env={**os.environ, **env},
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        self.lock = threading.Lock()
        self.ready = threading.Event()
        self.stopping = False
        self.context = 0
        self.workdir = tempfile.TemporaryDirectory(prefix="diffusiongemma-")
        threading.Thread(target=self._wait_ready, daemon=True).start()
        threading.Thread(target=self._watch, daemon=True).start()

    def _wait_ready(self) -> None:
        assert self.proc.stdout is not None
        with self.lock:
            for line in self.proc.stdout:
                fields = line.split()
                if fields[:1] == ["READY"]:
                    self.context = int(fields[2])
                    self.ready.set()
                    return

    def _watch(self) -> None:
        """Exit with the engine, so llama-swap sees the model as gone."""
        code = self.proc.wait()
        self.workdir.cleanup()
        os._exit(0 if self.stopping else code or 1)

    def stop(self) -> None:
        self.stopping = True
        self.proc.terminate()

    def run(self, request: dict[str, Any], emit: Callable[[str], None]) -> Result:
        """Run one request, calling emit(cumulative_text) per committed block.

        Always reads to the end of the engine's reply, even when the client is
        gone, so a stale record can never be taken for the next request's.
        """
        assert self.proc.stdin is not None and self.proc.stdout is not None
        result = Result()
        with self.lock:
            path = Path(self.workdir.name) / f"{uuid.uuid4().hex}.json"
            path.write_text(json.dumps(request), encoding="utf-8")
            try:
                self.proc.stdin.write(f"{path}\n")
                self.proc.stdin.flush()
                while True:
                    line = self.proc.stdout.readline()
                    if not line:
                        result.error = "engine exited"
                        break
                    tag, _, rest = line.rstrip("\n").partition(" ")
                    if tag == "C":
                        emit(json.loads(rest.split(" ", 1)[1]))
                    elif tag == "STATS":
                        result.stats = dict(pair.split("=", 1) for pair in rest.split())
                    elif tag == "DONE":
                        break
                    elif tag == "ERR":
                        result.error = rest
                        if rest.split(" ", 1)[0] not in ERRORS_BEFORE_DONE:
                            break
            finally:
                path.unlink(missing_ok=True)
        return result


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self, address: tuple[str, int], engine: Engine, args: argparse.Namespace
    ) -> None:
        super().__init__(address, Handler)
        self.engine = engine
        self.model_id: str = args.model_id
        self.default_max_tokens: int = args.default_max_tokens
        self.canvas: int = args.canvas
        self.thinking: bool = args.thinking


class Handler(BaseHTTPRequestHandler):
    server: Server  # pyright: ignore[reportIncompatibleVariableOverride]
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        print(f"diffusiongemma: {format % args}", file=sys.stderr, flush=True)

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_error_json(
        self, status: int, message: str, code: str | None = None
    ) -> None:
        kind = "invalid_request_error" if status < 500 else "server_error"
        self.send_json(
            status, {"error": {"message": message, "type": kind, "code": code}}
        )

    def do_GET(self) -> None:  # noqa: N802
        engine = self.server.engine
        if self.path == "/health":
            ready = engine.ready.is_set()
            self.send_json(
                200 if ready else 503, {"status": "ok" if ready else "loading"}
            )
        elif self.path == "/v1/models":
            model = {
                "id": self.server.model_id,
                "object": "model",
                "owned_by": "google",
                "context_window": engine.context,
            }
            self.send_json(200, {"object": "list", "data": [model]})
        else:
            self.send_error_json(404, f"no route for {self.path}")

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/v1/chat/completions":
            self.send_error_json(404, f"no route for {self.path}")
            return
        try:
            body = json.loads(
                self.rfile.read(int(self.headers.get("Content-Length", "0")))
            )
            if not isinstance(body, dict):
                raise ValueError("request body must be a JSON object")
            messages = normalize_messages(body.get("messages"))
        except ValueError as error:
            self.send_error_json(400, str(error))
            return
        if not self.server.engine.ready.is_set():
            self.send_error_json(503, "model is still loading")
            return
        self.complete(body, messages)

    def complete(self, body: dict[str, Any], messages: list[dict[str, Any]]) -> None:
        server = self.server
        thinking = wants_thinking(body, server.thinking)
        limit = body.get("max_completion_tokens") or body.get("max_tokens")
        max_tokens = (
            limit if isinstance(limit, int) and limit > 0 else server.default_max_tokens
        )
        n_blocks = max(1, math.ceil(max_tokens / server.canvas))
        seed = body.get("seed")
        request: dict[str, Any] = {
            "seed": seed if isinstance(seed, int) else random.getrandbits(31),
            "n_blocks": n_blocks,
            "enable_thinking": thinking,
            "messages": messages,
        }
        if body.get("tools") and body.get("tool_choice") != "none":
            request["tools"] = body["tools"]
        # After a tool result the template opens the thought channel itself.
        open_thought = thinking and messages[-1].get("role") == "tool"

        stream = bool(body.get("stream"))
        base = {
            "id": f"chatcmpl-{uuid.uuid4().hex}",
            "created": int(time.time()),
            "model": server.model_id,
        }
        sent = Parsed()
        state = StreamState()

        def chunk(
            delta: dict[str, Any], finish: str | None = None, **extra: Any
        ) -> None:
            if state.gone:
                return
            choice = {"index": 0, "delta": delta, "finish_reason": finish}
            payload = {
                **base,
                "object": "chat.completion.chunk",
                "choices": [choice],
                **extra,
            }
            try:
                if not state.open:
                    state.open = True
                    self.close_connection = True
                    self.send_response(200)
                    self.send_header("Content-Type", "text/event-stream")
                    self.send_header("Cache-Control", "no-cache")
                    self.send_header("Connection", "close")
                    self.end_headers()
                    first = {
                        **payload,
                        "choices": [{**choice, "delta": {"role": "assistant"}}],
                    }
                    self.wfile.write(f"data: {json.dumps(first)}\n\n".encode())
                self.wfile.write(f"data: {json.dumps(payload)}\n\n".encode())
                self.wfile.flush()
            except OSError:
                state.gone = True

        def emit(text: str) -> None:
            state.text = text
            if not stream:
                return
            now = parse_output(text, open_thought, final=False)
            if now.reasoning[len(sent.reasoning) :]:
                chunk({"reasoning_content": now.reasoning[len(sent.reasoning) :]})
                sent.reasoning = now.reasoning
            if now.content[len(sent.content) :]:
                chunk({"content": now.content[len(sent.content) :]})
                sent.content = now.content

        result = server.engine.run(request, emit)
        stats = result.stats
        self.log_message(
            "request done: %s",
            result.error or " ".join(f"{k}={v}" for k, v in stats.items()),
        )

        if result.error and not state.text:
            kind, _, detail = result.error.partition(" ")
            if kind == "toolong":
                needed, _, budget = detail.partition(" ")
                problem = f"prompt plus one block needs {needed} tokens but the context holds {budget}"
                self.send_error_json(400, problem, "context_length_exceeded")
            else:
                self.send_error_json(500, f"engine error: {result.error}")
            return

        final = parse_output(state.text, open_thought, final=True)
        predicted = int(stats.get("predicted_n", 0))
        if final.tool_calls:
            finish = "tool_calls"
        elif result.error or predicted >= n_blocks * int(
            stats.get("canvas", server.canvas)
        ):
            finish = "length"
        else:
            finish = "stop"
        prompt = int(stats.get("prompt_n", 0))
        decode_ms = float(stats.get("decode_ms", 0))
        extra = {
            "usage": {
                "prompt_tokens": prompt,
                "completion_tokens": predicted,
                "total_tokens": prompt + predicted,
            },
            "timings": {
                "predicted_n": predicted,
                "predicted_ms": decode_ms,
                "predicted_per_second": predicted * 1000 / decode_ms
                if decode_ms
                else 0,
                "denoising_steps": int(stats.get("steps", 0)),
            },
        }

        if stream:
            if final.content[len(sent.content) :]:
                chunk({"content": final.content[len(sent.content) :]})
            if final.tool_calls:
                chunk(
                    {
                        "tool_calls": [
                            {"index": i, **c} for i, c in enumerate(final.tool_calls)
                        ]
                    }
                )
            chunk({}, finish, **extra)
            if not state.gone:
                try:
                    self.wfile.write(b"data: [DONE]\n\n")
                except OSError:
                    pass
            return
        message: dict[str, Any] = {"role": "assistant", "content": final.content}
        if final.reasoning:
            message["reasoning_content"] = final.reasoning
        if final.tool_calls:
            message["tool_calls"] = final.tool_calls
        choice = {"index": 0, "message": message, "finish_reason": finish}
        self.send_json(
            200, {**base, "object": "chat.completion", "choices": [choice], **extra}
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--engine", required=True, help="llama-diffusion-gemma-visual-server binary"
    )
    parser.add_argument("--model", required=True, help="DiffusionGemma GGUF")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-id", default="diffusiongemma-26b-a4b-it")
    parser.add_argument("--default-max-tokens", type=int, default=4096)
    parser.add_argument(
        "--canvas", type=int, default=256, help="tokens per diffusion block"
    )
    parser.add_argument(
        "--thinking", action="store_true", help="think unless a request says otherwise"
    )
    parser.add_argument("--gpu-layers", type=int, default=99)
    parser.add_argument(
        "--context", type=int, default=0, help="token budget; 0 sizes it to free VRAM"
    )
    parser.add_argument("--flash-attention", action="store_true")
    args = parser.parse_args()

    env = {
        "NGL": str(args.gpu_layers),
        "MAXTOK": str(args.context),
        "FA": str(int(args.flash_attention)),
    }
    engine = Engine([args.engine, args.model], env)
    signal.signal(signal.SIGTERM, lambda *_: engine.stop())
    signal.signal(signal.SIGINT, lambda *_: engine.stop())
    Server((args.host, args.port), engine, args).serve_forever()


if __name__ == "__main__":
    main()
