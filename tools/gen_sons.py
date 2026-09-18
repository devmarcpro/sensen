# -*- coding: utf-8 -*-
"""LES SONS SYNTHÉTISÉS (ordre de travail 48, décision du 2026-09-14 — question 20 : « des sons synthétisés par un outil,
pas de fichiers achetés »). Chaque son est une petite recette déterministe — bruit filtré, sinus qui décroît, grincement
— écrite en WAV 16 bits mono dans godot/assets/sons/. Relancer l'outil redonne exactement les mêmes octets.

Un son par SOURCE du champ sonore (data/sonore.json → volumes) et par événement qui s'entend : le client joue celui dont
le nom est la source."""
import math, os, random, struct, wave

TAUX = 22050
ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, "..", "godot", "assets", "sons")


def passe_bas(x, a):
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def bruit(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def enveloppe(n, attaque, decroissance):
    out = []
    for i in range(n):
        t = i / TAUX
        a = min(1.0, t / attaque) if attaque > 0 else 1.0
        out.append(a * math.exp(-t / decroissance))
    return out


def mix(*pistes):
    n = max(len(p) for p in pistes)
    return [sum(p[i] for p in pistes if i < len(p)) for i in range(n)]


def normaliser(x, crete=0.85):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * crete / m for v in x]


def sinus(n, f0, f1=None, vib=0.0, vib_f=0.0):
    f1 = f0 if f1 is None else f1
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t + vib * math.sin(2 * math.pi * vib_f * i / TAUX)
        ph += 2 * math.pi * f / TAUX
        out.append(math.sin(ph))
    return out


def recette(nom, rng):
    if nom == "pas":
        n = int(0.09 * TAUX)
        b = passe_bas(bruit(n, rng), 0.08)
        e = enveloppe(n, 0.004, 0.025)
        return [b[i] * e[i] for i in range(n)]
    if nom == "coup":
        n = int(0.2 * TAUX)
        b = passe_bas(bruit(n, rng), 0.25)
        e = enveloppe(n, 0.001, 0.04)
        s = sinus(n, 140, 80)
        return [(b[i] * 0.7 + s[i] * 0.6) * e[i] for i in range(n)]
    if nom == "impact":
        n = int(0.3 * TAUX)
        b = passe_bas(bruit(n, rng), 0.05)
        e = enveloppe(n, 0.002, 0.07)
        s = sinus(n, 90, 45)
        return [(b[i] * 0.5 + s[i]) * e[i] for i in range(n)]
    if nom == "mort":
        n = int(0.7 * TAUX)
        s = sinus(n, 320, 110, vib=18, vib_f=7)
        b = passe_bas(bruit(n, rng), 0.15)
        e = enveloppe(n, 0.03, 0.3)
        return [(s[i] * 0.8 + b[i] * 0.25) * e[i] for i in range(n)]
    if nom == "porte":
        n = int(0.4 * TAUX)
        out, ph = [], 0.0
        for i in range(n):
            f = 45 + 25 * math.sin(2 * math.pi * 3.5 * i / TAUX) + rng.uniform(-4, 4)
            ph += 2 * math.pi * f / TAUX
            out.append(1.0 if (ph % (2 * math.pi)) < 0.35 else -0.1)
        out = passe_bas(out, 0.3)
        e = enveloppe(n, 0.02, 0.18)
        return [out[i] * e[i] for i in range(n)]
    if nom == "pioche":
        n = int(0.16 * TAUX)
        s = mix(sinus(n, 1850), [v * 0.6 for v in sinus(n, 2760)])
        b = bruit(n, rng)
        e = enveloppe(n, 0.0005, 0.03)
        return [(s[i] * 0.7 + b[i] * 0.4) * e[i] for i in range(n)]
    if nom == "effondrement":
        n = int(1.8 * TAUX)
        b = passe_bas(passe_bas(bruit(n, rng), 0.04), 0.1)
        e = enveloppe(n, 0.05, 0.6)
        chocs = [0.0] * n
        for _ in range(9):
            debut = rng.randint(0, int(n * 0.7))
            for k in range(int(0.06 * TAUX)):
                if debut + k < n:
                    chocs[debut + k] += rng.uniform(-1, 1) * math.exp(-k / (0.015 * TAUX))
        chocs = passe_bas(chocs, 0.2)
        return [b[i] * e[i] * 3.0 + chocs[i] * 0.8 for i in range(n)]
    if nom == "explosion":
        n = int(1.3 * TAUX)
        b = passe_bas(bruit(n, rng), 0.12)
        g = passe_bas(bruit(n, rng), 0.02)
        e = enveloppe(n, 0.003, 0.35)
        return [(b[i] * 0.6 + g[i] * 4.0) * e[i] for i in range(n)]
    if nom == "amb_vent":
        n = int(4.0 * TAUX)
        b = passe_bas(bruit(n, rng), 0.02)
        out = []
        for i in range(n):
            g = 0.55 + 0.45 * math.sin(2 * math.pi * 0.12 * i / TAUX) * math.sin(2 * math.pi * 0.037 * i / TAUX)
            out.append(b[i] * g)
        return out
    if nom == "amb_pluie":
        n = int(4.0 * TAUX)
        b = passe_bas(bruit(n, rng), 0.5)
        g = passe_bas(bruit(n, rng), 0.01)
        return [b[i] * (0.8 + 0.3 * g[i]) for i in range(n)]
    if nom == "amb_vagues":
        n = int(6.0 * TAUX)
        b = passe_bas(bruit(n, rng), 0.06)
        out = []
        for i in range(n):
            ph = (i / TAUX) % 3.0 / 3.0
            g = math.pow(math.sin(math.pi * ph), 3.0)
            out.append(b[i] * (0.15 + 0.95 * g))
        return out
    if nom == "amb_oiseaux":
        n = int(5.0 * TAUX)
        out = [0.0] * n
        for _ in range(26):
            debut = rng.randint(0, n - int(0.35 * TAUX))
            f0 = rng.uniform(1800, 3600)
            duree = int(rng.uniform(0.05, 0.16) * TAUX)
            for k in range(duree):
                t = k / duree
                out[debut + k] += math.sin(2 * math.pi * (f0 + 900 * t) * k / TAUX) * math.exp(-t * 3.0) * 0.5
        return out
    if nom == "amb_grillons":
        n = int(4.0 * TAUX)
        out = [0.0] * n
        i = 0
        while i < n:
            for k in range(int(0.012 * TAUX)):
                if i + k < n:
                    out[i + k] += math.sin(2 * math.pi * 4600 * k / TAUX) * math.exp(-k / (0.004 * TAUX)) * 0.6
            i += int(rng.uniform(0.05, 0.1) * TAUX)
        return passe_bas(out, 0.8)
    if nom == "amb_souterrain":
        n = int(5.0 * TAUX)
        b = passe_bas(passe_bas(bruit(n, rng), 0.01), 0.05)
        e = [0.6 + 0.4 * math.sin(2 * math.pi * 0.05 * i / TAUX) for i in range(n)]
        return [b[i] * e[i] * 3.0 for i in range(n)]
    if nom == "sifflet":
        n = int(0.9 * TAUX)
        s1 = sinus(n, 880, 860)
        s2 = sinus(n, 1175, 1150)
        b = passe_bas(bruit(n, rng), 0.3)
        e = enveloppe(n, 0.05, 0.5)
        return [(s1[i] * 0.5 + s2[i] * 0.4 + b[i] * 0.15) * e[i] for i in range(n)]
    raise KeyError(nom)


SONS = ["pas", "coup", "impact", "mort", "porte", "pioche", "effondrement", "explosion", "sifflet"]
AMBIANCES = ["amb_vent", "amb_pluie", "amb_vagues", "amb_oiseaux", "amb_grillons", "amb_souterrain"]


def main():
    os.makedirs(SORTIE, exist_ok=True)
    for nom in SONS + AMBIANCES:
        rng = random.Random("sensen-son-" + nom)
        x = normaliser(recette(nom, rng))
        chemin = os.path.join(SORTIE, nom + ".wav")
        with wave.open(chemin, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TAUX)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
        print(nom, os.path.getsize(chemin), "octets")


if __name__ == "__main__":
    main()
