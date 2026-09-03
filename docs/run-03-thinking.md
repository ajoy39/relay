# Run 03 — the thinking-model arm (abandoned with sufficient evidence)

2026-09-01/02. Question: does a reasoning-tuned variant of the same weights
(Qwen3-30B-A3B-Thinking-2507, same Q4, same N5) close the judgment gap the
instruct coder showed on brownfield work? Method: re-run the edit-framed ticket
0003 from the identical pre-merge commit — the instruct model's 0-for-3 baseline.

## What happened

- **Two silent no-ops.** The model's chain-of-thought overflowed the 8192-token
  output limit before reaching a tool call; opencode read an action-less turn as
  completion. Sessions ended after one file read, "successfully." Fix: raise the
  output ceiling to 20480. Finding: thinking models need materially larger output
  budgets than instruct models just to *act*, and their failure mode is silent.
- **Round 1 (90 min, timeout):** real work, at roughly a third of the instruct
  model's action rate (12 tool ops in 90 min — every action pays a deliberation
  tax at 15 tok/s). Ended with parser.py syntactically broken by stacked failed
  exact-string edits. (This round's tree was subsequently lost to a container
  restart; its results were recorded before the loss.)
- **Round 2 (90 min, clean start, lessons carried in prompt):** wrote its parser
  at the wrong path (`parser/src/parser.py`, outside the package), and when the
  tests couldn't import it, **edited the tests' import line to point at its
  file** — the first rule-2 violation by any model in this project. Also leaked
  malformed tool-call JSON into its output stream. 19/21 red. Reverted.
- **Round 3: aborted by the operator** — evidence judged sufficient.

## Verdict

The hypothesis inverted. Deliberation did not buy judgment; it bought slower
action and *better-argued rule-breaking* — the model reasoned its way to "the
contract must be wrong" where the instruct model, in six failing rounds, never
once touched a test. For agentic implementation work in this harness, the
instruct coder's "the environment is right, adapt to it" prior is worth more
than reasoning capacity. qwen3-coder-30b keeps the resident seat.

Also banked: thinking variants require output-limit headroom (silent no-op
otherwise), and their per-action latency roughly triples effective round cost at
equal wall-clock.

## What's next

The judgment-gap question moves to model *scale*: Qwen3-Next-80B-A3B on this
same box, weights streamed via mmap (~45GB against 48GB RAM — the overflow tax
is accepted, expected decode 1–3 tok/s, one overnight-sized round). Same
edit-framed ticket 0003 conditions, third arm of the same A/B. If scale closes
the gap that reasoning-tuning couldn't, the hardware conversation (64GB gaming
PC as fast 80B host; RAM upgrades when the crunch breaks) has its justification.
If not, the 30B + rewrite-framing playbook from run-02 stands as the local
ceiling, and it is — measured across five merged tickets — a perfectly workable
one.

## Postscript — the 80B arm, attempted and abandoned (2026-09-02/03)

Qwen3-Next-80B-A3B-Instruct Q4_K_M (~45GB) was downloaded and configured on the
N5, deliberately accepting mmap streaming against 48GB of RAM. It never served a
token. Three configurations, three failures:

1. `--n-gpu-layers 999` (inherited from the 30B config): the loader tries to
   allocate ~45GB of GTT on a 48GB box. Crash loop.
2. `--n-gpu-layers 0` (CPU-only, mmap streaming as intended): silent death ~0.6s
   into the load, mid-tokenizer, no error line — the host OOM killer, not the
   container (no cgroup limit was set) and not the image (pulls latest, so
   Qwen3-Next support was present; the model was recognized and read).
3. The remaining lever — dropping the ZFS ARC cap to ~2GB to hand the page cache
   every available byte — was **declined on operational grounds**: this NAS also
   serves live web services, and ARC is load-bearing for their latency.

**Finding.** A 45GB model does not fit a 48GB machine that has a real job. The
constraint isn't mmap or quantization — it's that the page cache needs room to
hold the working set, and a live filesystem plus a live workload are already
using it. "Accept the overflow tax" was a reasonable bet; the tax turned out to
be non-payable rather than merely expensive.

The scale question therefore moves off this box: the 80B belongs on the desktop
(5700X3D / 7800 XT) once its second 32GB kit is installed — 64GB holds the model
resident with no streaming at all, and the GPU takes attention + prefill. The N5
returns to its proven role as the always-on 30B implementer.
