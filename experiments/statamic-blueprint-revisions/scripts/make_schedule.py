#!/usr/bin/env python3
"""make_schedule.py <prefix> <per_arm> <first_port> <model> <phase> <seed>

Writes a run-08 trial schedule to stdout as the gate's schedule.tsv rows:
trial<TAB>arm<TAB>port<TAB>model<TAB>phase.

The order is block-randomized (PREREG-run-08.md, *Order*): per_arm blocks of
four, each a random permutation of A, B, C and D. That interleaves the arms by
construction, which a plain shuffle only does on average, so no arm's trials
can bunch together in time.

The seed must be fixed before any result exists. The pilot uses the commit of
relay main it was generated from, so anyone can regenerate the same order.
Trial IDs are <prefix>01, <prefix>02, ... in run order; ports count up from
first_port.
"""
import random
import sys


def main(argv):
    if len(argv) != 7:
        sys.exit(__doc__.strip().splitlines()[0])
    prefix, per_arm, first_port, model, phase, seed = argv[1:]
    rng = random.Random(seed)
    arms = []
    for _ in range(int(per_arm)):
        block = ["A", "B", "C", "D"]
        rng.shuffle(block)
        arms += block
    width = max(2, len(str(len(arms))))
    for i, arm in enumerate(arms):
        trial = f"{prefix}{i + 1:0{width}d}"
        print("\t".join([trial, arm, str(int(first_port) + i), model, phase]))


if __name__ == "__main__":
    main(sys.argv)
