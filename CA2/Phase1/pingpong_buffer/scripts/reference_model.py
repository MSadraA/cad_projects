#!/usr/bin/env python3
"""Independent exact-integer oracle; no host floating-point rounding.

All input values are integers in units of 2^-24. Addition is exact in that
domain; multiplication is exact in units of 2^-48. Only the final encoding
discards bits. Arithmetic is deliberately unrelated to the RTL datapath.
"""


def valid(word, zero_frac=True):
    return bool((word >> 10) & 31) and (not zero_frac or bool(word & 1023))


def decode(word):
    exp = (word >> 10) & 31
    magnitude = (1024 + (word & 1023)) << (exp - 1)
    return -magnitude if word & 0x8000 else magnitude


def encode(integer, fractional_bits, overflow_exp=31):
    if not integer:
        return 0
    sign = 0x8000 if integer < 0 else 0
    integer = abs(integer)
    top = integer.bit_length() - 1
    exponent = top - fractional_bits + 15
    if exponent <= 0:
        return 0
    if exponent >= 31:
        return sign | (overflow_exp << 10)
    significand = integer >> (top - 10)
    return sign | (exponent << 10) | (significand & 1023)


def add(a, b, zero_frac=True, overflow_exp=31):
    va, vb = valid(a, zero_frac), valid(b, zero_frac)
    if not va:
        return b if vb else 0
    if not vb:
        return a
    return encode(decode(a) + decode(b), 24, overflow_exp)


def multiply(a, b, zero_frac=True, overflow_exp=31):
    if not valid(a, zero_frac) or not valid(b, zero_frac):
        return 0
    return encode(decode(a) * decode(b), 48, overflow_exp)
