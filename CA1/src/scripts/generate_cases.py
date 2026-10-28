"""Create deterministic small networks for parameter/tail/reset verification.

Generated model and image files use the assignment's scalar FP16 format.
Example: python scripts/generate_cases.py --output build/custom --inputs 15
         --hidden 3 --outputs 5 --lanes 7 --latency 7 --seed 42
"""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from reference_model import to_bits, write_mem

ROOT = Path(__file__).resolve().parents[1]


def generate(destination: Path, ni: int, nh: int, no: int, lanes: int,
             latency: int, seed: int = 42) -> Path:
    if min(ni, nh, no, lanes, latency) < 1:
        raise ValueError('Dimensions and latency must be positive')
    destination = destination.resolve()
    model = destination / 'model'
    model.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    for filename, count, scale in [('fc1_weights.mem', ni*nh, .5), ('fc2_weights.mem', nh*no, .5),
                                   ('fc1_bias.mem', nh, .25), ('fc2_bias.mem', no, .25)]:
        write_mem(model / filename, [to_bits(rng.uniform(-scale, scale)) for _ in range(count)])
    patterns = {'zero': [0]*ni, 'negative': [to_bits(-1.0)]*ni,
                'alternating': [to_bits(1.0 if i % 2 else -1.0) for i in range(ni)],
                'random': [to_bits(rng.uniform(-1, 1)) for _ in range(ni)]}
    cases = []
    for name, words in patterns.items():
        image = destination / f'{name}.mem'
        write_mem(image, words)
        cases.append({'name': name, 'image': str(image)})
    suite = {'parameters': {'N_INPUTS': ni, 'N_HIDDEN': nh, 'N_OUTPUTS': no,
                            'LANES': lanes, 'SRAM_LATENCY': latency},
             'model_dir': str(model), 'cases': cases, 'seed': seed}
    output = destination / 'suite.json'
    output.write_text(json.dumps(suite, indent=2) + '\n', encoding='utf-8')
    return output


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--inputs', type=int, default=15)
    p.add_argument('--hidden', type=int, default=3)
    p.add_argument('--outputs', type=int, default=5)
    p.add_argument('--lanes', type=int, default=7)
    p.add_argument('--latency', type=int, default=7)
    p.add_argument('--seed', type=int, default=42)
    a = p.parse_args()
    print(generate(a.output, a.inputs, a.hidden, a.outputs, a.lanes, a.latency, a.seed))


if __name__ == '__main__':
    main()
