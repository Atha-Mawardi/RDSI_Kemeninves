"""Distribusi t Student tanpa SciPy: CDF lewat fungsi beta tak lengkap ter-regularisasi (pecahan berlanjut)."""

import math


def _betacf(a, b, x, iterasi=300, eps=3e-14):
    qab, qap, qam = a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / (d if abs(d) > 1e-300 else 1e-300)
    h = d
    for m in range(1, iterasi + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d
        d = 1 / (d if abs(d) > 1e-300 else 1e-300)
        c = 1 + aa / c if abs(1 + aa / c) > 1e-300 else 1e-300
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d
        d = 1 / (d if abs(d) > 1e-300 else 1e-300)
        c = 1 + aa / c if abs(1 + aa / c) > 1e-300 else 1e-300
        dl = d * c
        h *= dl
        if abs(dl - 1) < eps:
            break
    return h


def beta_inc(a, b, x):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    ln = math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b) + a * math.log(x) + b * math.log(1 - x)
    if x < (a + 1) / (a + b + 2):
        return math.exp(ln) * _betacf(a, b, x) / a
    return 1 - math.exp(ln) * _betacf(b, a, 1 - x) / b


def t_cdf(t, df):
    x = df / (df + t * t)
    p = 0.5 * beta_inc(df / 2, 0.5, x)
    return 1 - p if t > 0 else p


def p_dua_sisi(t, df):
    if not math.isfinite(t):
        return 0.0
    return 2 * (1 - t_cdf(abs(t), df))


def t_kritis(df, alfa=0.05):
    """Kuantil 1 − alfa/2 dengan bagi dua."""
    lo, hi = 0.0, 1000.0
    target = 1 - alfa / 2
    for _ in range(200):
        m = (lo + hi) / 2
        if t_cdf(m, df) < target:
            lo = m
        else:
            hi = m
    return (lo + hi) / 2


def bintang(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.1 else ""
