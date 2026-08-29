# The harness: opencode against the local endpoint

The implementer needs an agentic harness — the loop that reads the ticket, edits files, runs
commands, and iterates. This repo standardizes on **opencode**: terminal-native, Claude-Code-shaped,
provider-neutral (any OpenAI-compatible endpoint), with a non-interactive `opencode run` mode that
`scripts/dispatch.sh` drives.

## Install

```sh
curl -fsSL https://opencode.ai/install | bash    # or: npm i -g opencode-ai / brew install opencode
opencode --version
```

## Point it at the N5

The repo ships `opencode.json` declaring a `local` provider that reads the endpoint from the
environment — so the config is committed, the secrets never are:

```sh
export OPENAI_BASE_URL="http://<n5>:8080/v1"   # LAN/tailnet IP, or the tunnel hostname
export OPENAI_API_KEY="<the llama-server --api-key value>"
export RELAY_MODEL="<model id from /v1/models>"
```

Verify the plumbing before blaming anything else:

```sh
curl -s "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"
```

Then interactively (`opencode`, pick the `local` provider) ask something trivial — confirm tool
calls work, since agentic use lives and dies on the model's tool-calling reliability, not its
chat quality. If your opencode version doesn't substitute `{env:...}` in config, paste the URL
into `opencode.json` locally and **don't commit it**.

## Non-interactive dispatch

What `scripts/dispatch.sh` runs, approximately:

```sh
opencode run --model "local/$RELAY_MODEL" "$(cat /tmp/ticket-prompt.md)"
```

The prompt is the ticket plus the implementer rules from
[`protocol.md`](protocol.md#implementer-rules-injected-into-every-dispatch). The harness works in
the current checkout on the ticket branch; gates run between rounds; three red rounds escalates.

## Expectations management

- **Tool-call reliability is the real model benchmark here.** A model that chats brilliantly but
  fumbles function calls will burn rounds. Prefer models explicitly tuned for agentic/tool use.
- **Context discipline**: keep `--ctx-size` on the server ≥ what the harness needs (32K is a sane
  floor for this repo's tickets). Prefill on the N5 is slow — the harness re-reading a large repo
  is where wall-clock goes. Small repos and scoped tickets aren't a style preference; they're a
  performance strategy.
- **One dispatch at a time** against the N5 (`--parallel 1`); it's a NAS with a day job.

## Alternatives, for when this setup outgrows itself

- **OpenHands** — heavier, self-hosted control plane, strongest for fully unattended multi-step
  runs; the natural next step if dispatches start running overnight without supervision.
- **Aider** — leanest scriptable option (`aider --message`), git-native, surgical; a good fallback
  if opencode misbehaves headless in some environment.

The protocol doesn't care which harness runs — tickets, gates, and review are harness-agnostic by
construction. That's deliberate: harnesses are having a fast year, and the seam should survive
switching.
