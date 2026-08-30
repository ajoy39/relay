# Serving the implementer from the N5 Pro

Target: a Minisforum N5 Pro (AMD Ryzen AI 9 HX PRO 370, Radeon 890M iGPU, 48GB DDR5) running
TrueNAS SCALE, serving an OpenAI-compatible endpoint via **llama.cpp**. Always-on, in the closet,
already paid for.

Set expectations first: dual-channel DDR5 gives roughly ~90GB/s of memory bandwidth. That's the
budget everything below is spent against. **Decode will be genuinely usable with the right model
shape; prefill (prompt processing) is the slow part** — which an agentic harness feels, because
agents re-read constantly. This is exactly the "slower but yours" trade, quantified.

One disappointment to swallow up front: the 50-TOPS XDNA NPU is **not usable by llama.cpp** — its
software path doesn't serve this workload. You're using CPU cores and/or the 890M via Vulkan.
Ignore the NPU marketing for this purpose.

## 1. Model choice: shape beats size

The constraint is bandwidth, so the winning shape is **MoE with few active parameters**: big total
(knowledge), small active (bytes moved per token).

| Pick | Why |
|---|---|
| **Qwen3-Coder-30B-A3B class, GGUF Q4_K_M (~18–19GB)** | ~3B active params → ~2GB touched per token → 20–30+ tok/s on this box. The default. |
| Dense ~14B coder Q4 (~9GB) | Fallback if RAM pressure bites; noticeably dumber |
| Dense 24–32B Q4 | Fits, but ~4–8 tok/s decode — only if quality demands it |

Check what the current best small-active MoE coder is before downloading — this table rots in
months. Grab GGUFs from the model's official Hugging Face repo.

## 2. ZFS will fight the model for RAM — cap the ARC

48GB is shared between the model (~19GB), KV cache (a few GB at 32K context), llama.cpp overhead,
NAS duties, and ZFS's ARC, which by default happily takes half of RAM. Cap it:

```
# TrueNAS SCALE: System Settings → Advanced → Sysctl (or init script)
# Cap ARC at 8GiB — tune to taste, but the model must never swap:
echo 8589934592 > /sys/module/zfs/parameters/zfs_arc_max
```

Budget check: 19 (model) + 4 (KV) + 2 (runtime) + 8 (ARC) + headroom ≈ comfortable in 48GB. If you
see swapping, shrink ARC or context length first, not the model.

## 3. llama.cpp as a TrueNAS app

Run the official container as a Custom App (Docker):

- **Image**: `ghcr.io/ggml-org/llama.cpp:server-vulkan` (Vulkan build for the 890M; if iGPU proves
  finicky, the plain `server` CPU image on 12 Zen 5 cores is a perfectly credible fallback — MoE
  with 3B active runs acceptably on CPU).
- **GPU** (Vulkan only): enable the app's **"passthrough available (non-NVIDIA) GPUs"** toggle —
  it mounts `/dev/dri` and sets permissions for you. (Manually adding `/dev/dri` under Devices
  works too; use one mechanism, not both, and beware trailing whitespace in hand-typed paths.)
- **Storage**: host-path a dataset like `/mnt/tank/models` → `/models`.
- **Entrypoint vs Command** — the Docker-backend custom app form (TrueNAS 24.10 "Electric Eel"
  and later) uses Docker's naming: *Entrypoint* is the binary, *Command* is the arguments
  appended to it. **Leave Entrypoint empty** (the image already runs `llama-server`); the flags
  go in **Command**, and each token is its own entry — there is no shell doing word-splitting,
  so `--port 8080` as one entry breaks. Enter, in order:

```
--model
/models/<your-model>.gguf
--ctx-size
32768
--n-gpu-layers
999
--host
0.0.0.0
--port
8080
--parallel
1
--jinja
--alias
qwen3-coder-30b
```

  Notes: `--n-gpu-layers 999` means "offload everything" — Vulkan image only, omit both entries
  on the CPU image. `--jinja` enables the model's own chat template, which modern coder models
  need for tool calls. `--alias` sets the model name the API reports; whatever you choose here
  is the exact string `RELAY_MODEL` must be set to at dispatch time.
- **API key**: no shell also means `${VAR}` in Args is passed as a literal string, not expanded.
  Set the key in the app's **environment variables** instead: `LLAMA_ARG_API_KEY=<your-key>`
  (every `--flag` has a `LLAMA_ARG_*` env twin). Generate a throwaway secret — `openssl rand
  -hex 32` — reused nowhere else: it sits in the app's stored config and protects only this
  endpoint.
- **Port**: expose 8080 on the LAN.

First-start check: the app logs should show Vulkan enumerating the Radeon 890M and then layer
offload lines. CPU-only warnings mean the `/dev/dri` passthrough didn't take — fix that before
touching anything else.

Smoke test from anything on the network:

```sh
curl -s http://<n5-lan-ip>:8080/v1/models -H "Authorization: Bearer $LLAMA_API_KEY"
```

## 4. Reachability tiers — in order of preference

1. **LAN**: `OPENAI_BASE_URL=http://<n5-lan-ip>:8080/v1`. The steady state.
2. **Tailscale**: same, via the tailnet IP/MagicDNS name. Still your network; nothing traverses a
   third party. (The N5 joins the *personal* tailnet or gets shared to it — don't put a personal
   inference box on the employer's tailnet.)
3. **Cloudflare tunnel** — opt-in remote access, e.g. for letting a cloud agent drive the loop:

```sh
cloudflared tunnel create relay-llm
# route e.g. llm.<your-domain> to http://localhost:8080 in the tunnel config
```

   Two rules when the tunnel is up: **auth is mandatory** (the `--api-key` above at minimum;
   Cloudflare Access with a service token is better — an open OpenAI-compatible endpoint on a
   public hostname gets found and farmed within days), and **know what you're trading**: prompts
   and code now transit Cloudflare. Fine deliberately, never accidentally. Tear the route down
   when the remote use case ends.

## 5. The M2 Max, for the heavy tail

The MacBook (M2 Max, 400GB/s) serves ad hoc when a ticket needs a bigger or denser model than the
N5 can move: LM Studio or `llama-server` on the Mac, same flags, and point `OPENAI_BASE_URL` at it
for that dispatch only. The scripts don't care — the endpoint is a URL. Escalation rule applies
before heroics: three red rounds means rethink, not a bigger hammer by reflex.
