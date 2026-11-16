#!/usr/bin/env python3
"""GPU-free test of modules/services/diffusiongemma/server.py.

Usage: python scripts/test-diffusiongemma-server.py
A fake engine speaks llama-diffusion-gemma-visual-server's line protocol; its
reply depends on the last message, so no weights are loaded.
"""

from __future__ import annotations

import importlib.util
import json
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

SERVER = (
    Path(__file__).resolve().parent.parent / "modules/services/diffusiongemma/server.py"
)

FAKE_ENGINE = r"""
import json, os, sys
print("READY 262144 8192", flush=True)
REPLIES = {
    "plain": ["Hello ", "world<turn|>ignored"],
    "think": ['<|channel>thought\nweighing it<channel|>', "The answer."],
    "tool": ["Checking. <|tool_call>call:get_weather{city:<|\"|>Oslo, NO<|\"|>,",
             "days:3,units:{temp:<|\"|>C<|\"|>},tags:[<|\"|>a<|\"|>,true,null]}<tool_call|><|tool_response>junk"],
    "after-tool": ["still thinking<channel|>", "Done."],
    "env": [json.dumps({k: os.environ.get(k) for k in ("NGL", "MAXTOK", "FA")})],
}
for line in sys.stdin:
    path = line.strip()
    if path == "QUIT":
        break
    request = json.load(open(path))
    last = request["messages"][-1]["content"]
    if last == "badreq":
        print("ERR parse nope", flush=True)
        continue
    if last == "toolong":
        print("ERR toolong 9000 8192\nDONE", flush=True)
        continue
    if last == "echo":
        blocks = [json.dumps({k: request.get(k) for k in ("n_blocks", "enable_thinking", "tools")})]
    else:
        blocks = REPLIES[last]
    text = ""
    for i, block in enumerate(blocks):
        print(f"F {i} 0 48 {json.dumps('noise')}", flush=True)
        text += block
        print(f"C {i} {json.dumps(text)}", flush=True)
    print(f"STATS prompt_n=11 predicted_n=7 decode_ms=100.0 blocks={len(blocks)} steps=14 canvas=256", flush=True)
    print("DONE", flush=True)
"""


def post(port: int, body: dict[str, Any]) -> tuple[int, Any]:
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw = response.read().decode()
            status = response.status
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())
    if body.get("stream"):
        events = [line[6:] for line in raw.splitlines() if line.startswith("data: ")]
        assert events[-1] == "[DONE]", events
        return status, [json.loads(event) for event in events[:-1]]
    return status, json.loads(raw)


def ask(port: int, content: str, **extra: Any) -> tuple[int, Any]:
    return post(port, {"messages": [{"role": "user", "content": content}], **extra})


def check_parser() -> None:
    spec = importlib.util.spec_from_file_location("dg_server", SERVER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules["dg_server"] = module
    spec.loader.exec_module(module)
    held = module.parse_output(
        "Hi <|tool_call>call:f{a:1", open_thought=False, final=False
    )
    assert (held.content, held.tool_calls) == ("Hi", []), held
    broken = module.parse_output(
        "Hi <|tool_call>call:f{a:1", open_thought=False, final=True
    )
    assert broken.content == "Hi<|tool_call>call:f{a:1" and not broken.tool_calls, (
        broken
    )
    assert module.wants_thinking({}, True) and not module.wants_thinking({}, False)
    assert not module.wants_thinking({"reasoning_effort": "none"}, True)
    assert module.wants_thinking({"reasoning_effort": "low"}, False)
    kwargs = {
        "chat_template_kwargs": {"enable_thinking": False},
        "reasoning_effort": "high",
    }
    assert not module.wants_thinking(kwargs, True)


def main() -> None:
    check_parser()
    with tempfile.TemporaryDirectory() as tmp:
        engine = Path(tmp) / "engine"
        engine.write_text(f"#!{sys.executable}\n{FAKE_ENGINE}")
        engine.chmod(0o755)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        command = [
            sys.executable,
            str(SERVER),
            "--engine",
            str(engine),
            "--model",
            "x.gguf",
        ]
        command += ["--port", str(port), "--context", "8192", "--flash-attention"]
        shim = subprocess.Popen(command)
        try:
            for _ in range(100):
                try:
                    with urllib.request.urlopen(
                        f"http://127.0.0.1:{port}/health", timeout=1
                    ) as health:
                        if health.status == 200:
                            break
                except OSError:
                    time.sleep(0.1)
            else:
                raise AssertionError("shim never became healthy")
            with urllib.request.urlopen(
                f"http://127.0.0.1:{port}/v1/models"
            ) as response:
                model = json.load(response)["data"][0]
            assert (
                model["id"] == "diffusiongemma-26b-a4b-it"
                and model["context_window"] == 8192
            ), model

            status, reply = ask(port, "env")
            assert json.loads(reply["choices"][0]["message"]["content"]) == {
                "NGL": "99",
                "MAXTOK": "8192",
                "FA": "1",
            }

            status, reply = ask(port, "plain")
            choice = reply["choices"][0]
            assert status == 200 and choice["message"]["content"] == "Hello world", (
                reply
            )
            assert (
                choice["finish_reason"] == "stop"
                and reply["usage"]["total_tokens"] == 18
            ), reply

            status, reply = ask(port, "think")
            message = reply["choices"][0]["message"]
            assert (message["reasoning_content"], message["content"]) == (
                "weighing it",
                "The answer.",
            ), reply

            status, reply = ask(port, "tool")
            choice = reply["choices"][0]
            call = choice["message"]["tool_calls"][0]["function"]
            expected = {
                "city": "Oslo, NO",
                "days": 3,
                "units": {"temp": "C"},
                "tags": ["a", True, None],
            }
            assert (
                call["name"] == "get_weather"
                and json.loads(call["arguments"]) == expected
            ), reply
            assert (
                choice["finish_reason"] == "tool_calls"
                and choice["message"]["content"] == "Checking."
            ), reply

            # A tool result with thinking on: the prompt already opened the thought channel.
            messages = [
                {"role": "user", "content": "x"},
                {"role": "tool", "content": "after-tool"},
            ]
            status, reply = post(
                port, {"messages": messages, "reasoning_effort": "high"}
            )
            message = reply["choices"][0]["message"]
            assert (message["reasoning_content"], message["content"]) == (
                "still thinking",
                "Done.",
            ), reply

            tools = [{"type": "function", "function": {"name": "f"}}]
            status, reply = ask(
                port, "echo", max_tokens=600, tools=tools, reasoning_effort="none"
            )
            echoed = json.loads(reply["choices"][0]["message"]["content"])
            assert echoed == {
                "n_blocks": 3,
                "enable_thinking": False,
                "tools": tools,
            }, echoed
            status, reply = ask(
                port,
                "echo",
                chat_template_kwargs={"enable_thinking": True},
                tool_choice="none",
            )
            echoed = json.loads(reply["choices"][0]["message"]["content"])
            assert echoed == {"n_blocks": 16, "enable_thinking": True, "tools": None}, (
                echoed
            )

            status, chunks = ask(port, "think", stream=True)
            deltas = [chunk["choices"][0]["delta"] for chunk in chunks]
            assert deltas[0] == {"role": "assistant"}, deltas
            assert (
                "".join(d.get("reasoning_content", "") for d in deltas) == "weighing it"
            ), deltas
            assert "".join(d.get("content", "") for d in deltas) == "The answer.", (
                deltas
            )
            assert (
                chunks[-1]["choices"][0]["finish_reason"] == "stop"
                and "usage" in chunks[-1]
            ), chunks[-1]

            status, chunks = ask(port, "tool", stream=True)
            deltas = [chunk["choices"][0]["delta"] for chunk in chunks]
            assert "".join(d.get("content", "") for d in deltas) == "Checking.", deltas
            calls = [call for d in deltas for call in d.get("tool_calls", [])]
            assert (
                len(calls) == 1
                and calls[0]["index"] == 0
                and calls[0]["function"]["name"] == "get_weather"
            ), calls
            assert chunks[-1]["choices"][0]["finish_reason"] == "tool_calls", chunks[-1]

            status, reply = ask(port, "toolong", stream=True)
            assert (
                status == 400 and reply["error"]["code"] == "context_length_exceeded"
            ), reply
            status, reply = ask(port, "badreq")
            assert status == 500 and "parse" in reply["error"]["message"], reply
            image = [{"type": "image_url", "image_url": {"url": "data:"}}]
            status, reply = post(
                port, {"messages": [{"role": "user", "content": image}]}
            )
            assert status == 400 and "text only" in reply["error"]["message"], reply
            # Errors must leave the engine in step with the next request.
            status, reply = ask(port, "plain")
            assert reply["choices"][0]["message"]["content"] == "Hello world", reply

            shim.terminate()
            assert shim.wait(timeout=10) == 0, (
                "SIGTERM should stop the engine and exit cleanly"
            )
        finally:
            shim.kill()
    print("ok")


if __name__ == "__main__":
    main()
