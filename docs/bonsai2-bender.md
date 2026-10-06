# Bonsai 2 on Bender

Bender serves `bonsai-2-27b` through an OpenAI-compatible endpoint at
`http://bender:8080/v1`. `llama-swap` keeps the endpoint available and starts the
Metal backend on the first request. It unloads the model after 600 idle seconds so
the Mac returns unified memory to OpenClaw and normal macOS workloads.

## Hardware and capacity

Collected from Bender before enabling the model on 2026-10-06:

- Mac mini `Mac16,10` (`MU9D3LL/A`)
- Apple M4: 4 performance CPU cores, 6 efficiency CPU cores, 10 GPU cores
- 16 GB unified memory
- 256 GB internal Apple SSD (`APPLE SSD AP0256Z`)
- 67,826,548,736 bytes free across the shared APFS container (63.2 GiB)
- 23,382,328 KiB used by `/nix/store`
- no swap in use and 82% reported system-wide memory free during inspection

The pinned PQ2_0 language model is 7,206,168,928 bytes and the Q8_0 vision
projector is 629,246,976 bytes: 7.30 GiB combined. The pre-download free-space
margin was therefore 55.9 GiB before accounting for the comparatively small
runtime closure and build intermediates.

Disk capacity is sufficient. Unified memory is the limiting resource.

## Bender-specific wiring

`modules/services/bonsai2-darwin.nix` defines the service and
`hosts/bender/default.nix` enables it. The model and projector are immutable,
content-addressed `fetchurl` derivations pinned to Hugging Face revision
`b072e1d3b35a0a630cece372c2127528e0994386`.

The runtime is intentionally different from Hal 9000:

| Setting     | Bender                             | Reason                                                                                                    |
| ----------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Runtime     | PrismML llama.cpp fork, Metal      | Stock llama.cpp does not implement all Bonsai 2 transforms or PQ2_0 kernels.                              |
| Packing     | PQ2_0                              | Fastest measured Apple Silicon packing for both prompt processing and decode.                             |
| GPU offload | All layers (`--n-gpu-layers 99`)   | M4 unified memory avoids PCIe transfers.                                                                  |
| Context     | 16,384 tokens                      | PrismML's safe automatic tier for Macs with 12–23 GB RAM.                                                 |
| Slots       | 1                                  | Avoids dividing the small context and prevents concurrent requests from multiplying active state.         |
| KV cache    | F16                                | Best conservative performance choice at the 16K memory-safe context.                                      |
| Vision      | Q8_0 projector, 1,024 image tokens | Retains Hal's multimodal capability while bounding image prefill and applying the grounding workaround.   |
| Speculation | Disabled                           | Bonsai 2 has no official drafter; PrismML does not recommend the older speculative path on Apple Silicon. |
| Idle unload | 600 seconds                        | Prevents a roughly 8–10 GB model/runtime working set from remaining resident.                             |
| Listener    | `0.0.0.0:8080`                     | Makes the headless Mac's endpoint available to trusted LAN/Tailscale clients, matching Hal's API port.    |

The backend itself binds to loopback on a dynamic port owned by `llama-swap`.
Only the proxy listens on the network. There is no API authentication; do not
expose port 8080 to the public Internet.

## Expected performance

PrismML's published M4 Pro 64 GB result for PQ2_0 is 126.89 prompt tokens/s and
20.53 generated tokens/s. Bender has a base M4 with less memory bandwidth and
fewer GPU resources, so those numbers are an upper bound rather than a Bender
claim. PQ2_0 remains the performance choice: on the same M4 Pro, PTQ1_0 measured
98.58 prompt tokens/s and 17.30 generated tokens/s.

Observed on Bender after deployment:

- cold OpenAI-compatible request: HTTP 200 with exact answer `77` in 30.50 seconds,
  including model load
- backend timing for that request: 15.56 prompt tokens/s and 10.97 generated
  tokens/s
- loaded model remained responsive with 68% reported memory free; macOS had moved
  553 MiB of inactive data to swap
- OMP selected `@bonsai2_bender` and returned exact `OMP_BENDER_OK`

Primary references:

- [Official Bonsai 2 model card](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf)
- [PrismML backend support matrix](https://github.com/PrismML-Eng/Bonsai-demo/blob/main/BACKEND-SUPPORT.md)
- [PrismML setup and serving guide](https://github.com/PrismML-Eng/Bonsai-demo)
- [Bonsai 2 known issues](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/blob/main/KNOWN_ISSUES.md)
- [M4 Pro Metal benchmark](https://github.com/PrismML-Eng/Bonsai-demo/blob/main/community-benchmarks/bonsai2/metal-m4-pro-64gb-macos.md)

## Operations

List the advertised model:

```bash
curl --fail --silent http://bender:8080/v1/models | jq
```

Run a bounded smoke request. `reasoning_effort: medium` is preferred on this
16K deployment because the model's default `xhigh` reasoning can consume the
output budget before returning an answer.

```bash
curl --fail --silent http://bender:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "bonsai-2-27b",
    "messages": [{"role": "user", "content": "What is 7 times 11? Return only the number."}],
    "reasoning_effort": "medium",
    "max_tokens": 1024,
    "temperature": 0
  }' | jq
```

Inspect the proxy and backend log:

```bash
ssh bender 'tail -n 100 /tmp/bonsai2.log'
```

A cold request includes model load time. Requests within the ten-minute TTL reuse
the loaded model and prompt cache.
