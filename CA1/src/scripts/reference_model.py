"""Independent binary16 oracle. Only Python's standard library is required.

Each product and each addition rounds separately to nearest, ties to even.
Binary16 operands have enough significant bits for binary64 to represent their
exact product or sum before the single struct.pack('e') rounding step.
"""
from __future__ import annotations

import math
import re
import struct
from pathlib import Path

QNAN = 0x7E00


def to_float(word: int) -> float:
    return struct.unpack('>e', struct.pack('>H', word))[0]


def to_bits(value: float) -> int:
    if math.isnan(value):
        return QNAN
    try:
        return struct.unpack('>H', struct.pack('>e', value))[0]
    except OverflowError:
        return 0xFC00 if value < 0 else 0x7C00


def add(a: int, b: int) -> int:
    return to_bits(to_float(a) + to_float(b))


def mul(a: int, b: int) -> int:
    return to_bits(to_float(a) * to_float(b))


def relu(word: int) -> int:
    if math.isnan(to_float(word)):
        return QNAN
    return 0 if word & 0x8000 else word


def argmax(words: list[int]) -> int:
    # Lower index wins ties; numeric values outrank NaNs; all NaN -> zero.
    if not words:
        raise ValueError('argmax requires at least one word')
    best = 0
    for index in range(1, len(words)):
        candidate, current = to_float(words[index]), to_float(words[best])
        if not math.isnan(candidate) and (math.isnan(current) or candidate > current):
            best = index
    return best


def read_mem(path: Path, count: int | None = None) -> list[int]:
    """Accept exactly the assignment's scalar, four-hex-digit file format."""
    words = []
    for line_number, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        text = line.split('//', 1)[0].strip()
        if not text:
            continue
        if not re.fullmatch(r'[0-9a-fA-F]{4}', text):
            raise ValueError(f'{path}:{line_number}: expected one 16-bit hex word')
        words.append(int(text, 16))
    if count is not None and len(words) != count:
        raise ValueError(f'{path}: got {len(words)} words, expected {count}')
    return words


def write_mem(path: Path, words: list[int]) -> None:
    path.write_text(''.join(f'{word:04x}\n' for word in words), encoding='ascii')


def dense(inputs: list[int], weights: list[int], biases: list[int], *, bias_first: bool = False) -> list[int]:
    """Neuron-major reference; intentionally independent of SRAM/PP layout."""
    width = len(inputs)
    if len(weights) != width * len(biases):
        raise ValueError('weight dimensions do not match input and bias dimensions')
    outputs = []
    for neuron, bias in enumerate(biases):
        acc = bias if bias_first else 0
        for index, value in enumerate(inputs):
            product = mul(weights[neuron * width + index], value)
            acc = add(acc, product)
        outputs.append(acc if bias_first else add(acc, bias))
    return outputs


def evaluate(model_dir: Path, image_file: Path, n_inputs: int, n_hidden: int,
             n_outputs: int, *, bias_first: bool = False) -> dict:
    image = read_mem(image_file, n_inputs)
    w1 = read_mem(model_dir / 'fc1_weights.mem', n_inputs * n_hidden)
    w2 = read_mem(model_dir / 'fc2_weights.mem', n_hidden * n_outputs)
    b1 = read_mem(model_dir / 'fc1_bias.mem', n_hidden)
    b2 = read_mem(model_dir / 'fc2_bias.mem', n_outputs)
    pre_hidden = dense(image, w1, b1, bias_first=bias_first)
    hidden = [relu(word) for word in pre_hidden]
    logits = dense(hidden, w2, b2, bias_first=bias_first)
    return {'pre_hidden': pre_hidden, 'hidden': hidden, 'logits': logits,
            'predicted_digit': argmax(logits), 'bias_order': 'first' if bias_first else 'last'}
