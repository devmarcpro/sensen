---
aliases: ["Transcription du catalogue de modules", "Modules — dette de format", "Décision — Transcription des modules"]
tags: [combat, contenu, données, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Résolu le 2026-08-26 — la passe est faite
> Les **61 modules** sont transcrits dans le schéma : `cout_ticks` sur les 61, `forme`/`portée`/`cible`/`ligne de vue` explicites, durées en ticks, quatre entrées périmées réécrites, et **les modules de manuel coûtent de l'endurance**. Catalogue à jour : [[Modules]] · JSON : `godot/data/modules/*.json`. Cette note conserve l'audit et les barèmes qui ont servi.

> [!failure] Le défaut, tel qu'il a été trouvé le 2026-08-26
> **Le catalogue [[Modules]] ne respecte pas le schéma que [[Vocabulaire des modules — six axes]] déclare pour lui.** Il a été converti *verbatim* depuis l'annexe F.2 du GDD, écrite **avant le pivot tactique** — donc en prose, en tours, et sans coût en ticks. C'est la dette de format la plus lourde du coffre.

Ce qui manque au catalogue des 61 modules pour être transcrivible en JSON, et comment le combler.

## L'architecture est bonne — c'est le catalogue qui traîne

Les modules sont décrits sur **quatre couches**, et les trois premières sont saines :

| Couche | Note | État |
|---|---|---|
| **Le pourquoi** | [[Le vocabulaire des modules et l'absence d'arbre de talents]] | ✅ |
| **Le schéma** — six axes, JSON de référence | [[Vocabulaire des modules — six axes]] | ✅ |
| **La grammaire** — six types, séquence lue de gauche à droite | [[Six types de modules et assemblage]] | ✅ |
| **Le catalogue** — les 61 entrées | [[Modules]] | ❌ à l'audit · ✅ **depuis la transcription** |

Autour : [[Structure compétences-modules-slots]] (combien de slots), [[Grimoires et manuels]] (comment on les obtient), [[Domaines de grimoires et manuels]] (les domaines), [[Mana]] et [[Endurance]] (les économies), [[Familles de capacités de la grille]] (ce que la grille rend possible).

## L'audit, chiffré

Sur les **61 entrées** (44 grimoire · 17 manuel — 47 effets, 12 modificateurs, 2 déclencheurs) :

| Champ exigé par le schéma | Renseigné |
|---|---|
| `cout_mana` | **61 / 61** ✅ |
| `module_type` | **61 / 61** ✅ |
| `forme` | ~19 / 61 — et seulement *devinable* dans la prose (« en cercle 3 tuiles ») |
| `portee` `[min, max]` | ~11 / 61 — le plus souvent « à distance » |
| `cible`, `ligne_de_vue` | ~0 / 61 |
| `conditions` | 1 / 61 |
| **`cout_ticks`** | **0 / 61** ❌ |
| `power_base` | exprimé en **dés** (`2d6`), pas en valeur |

`cout_ticks` à zéro est le point grave : **le combat de Sensen est une horloge** ([[Action-time à ticks]], [[Boucle de tick]]). Un module sans coût en ticks n'est pas jouable — c'est le champ qui décide si un module est un ouvre-chaîne rapide ou une frappe lente et dévastatrice ([[Jauge de chaîne Wu Xing]]).

## Le vocabulaire périmé

Onze entrées emploient des unités ou des mécaniques que le pivot a supprimées :

| Reste du GDD | Modules concernés | Pourquoi c'est faux |
|---|---|---|
| durées **en tours** | Trait incendiaire, Prison de glace, Orage local, Peau de pierre, Régénération, Terreur, Mur de lames, Brise-garde | **il n'y a pas de tours** — une horloge partagée avancée par les actions ([[Action-time à ticks]]). Les durées se disent en **ticks** |
| durées **en secondes / minutes** | Cœur de braise (5 s), Poche dimensionnelle (10 min) | idem — sauf effet réellement hors combat, à trancher au cas par cas |
| **« dés d'armure »** | Peau de pierre, Brise-garde | la mitigation par dés est **supprimée**, remplacée par la réduction plate par zone ([[Armure par zone et constructions]]) |
| **« +2 toucher »** | Duelliste | le jet de toucher d'E.3 est superseded par le pivot ([[Pipeline de résolution du combat]]) |

## Ce qui a été fait — la passe, six décisions par module

1. **`forme`** — extraire la géométrie de la prose, ou la trancher (`cible_unique` par défaut).
2. **`portee [min, max]`** — chiffrer ; un `min > 1` là où la contrepartie de la distance a du sens (l'arc long est mauvais au contact).
3. **`cible`** et **`ligne_de_vue`** — déductibles de l'effet dans presque tous les cas.
4. **`cout_ticks`** — **la vraie décision**. Barème proposé, calé sur l'attaque d'arme de référence (une épée = 5 ticks) :

| Rôle du module | `cout_ticks` |
|---|---|
| modificateur (n'agit pas seul) | **0** — le surcoût est porté par le noyau |
| déclencheur | **0** |
| effet rapide, faible (Choc statique, Trait de mana, Pas de côté) | **4 – 6** |
| effet standard (Projectile de feu, Soin mineur, Frappe lourde) | **8 – 12** |
| effet lourd ou de zone (Nova ardente, Séisme mineur, Balayage) | **14 – 20** |
| effet majeur (Orage local, Appel corrompu, Rappel) | **22 – 30** |

   Règle : `cout_ticks` suit `cout_mana` de près mais pas exactement — **les écarts sont exactement ce qui crée les archétypes** (un module cher en mana et rapide en ticks est un module de burst ; l'inverse est un module d'attrition).
5. **Durées en ticks** — convertir. Proposition d'étalon : **1 tour du GDD = 10 ticks** (une attaque d'épée à 2.0 att./10 ticks). « brûlure 3 tours » → `30 ticks`.
6. **Réécrire les quatre entrées périmées** — Peau de pierre et Brise-garde en réduction plate, Duelliste sans jet de toucher.

## La question qui a été tranchée

> [!success] Tranché : **les modules de manuel coûtent de l'endurance, jamais du mana**
> Le catalogue leur donne à tous un `cout_mana`. Mais [[Vocabulaire des modules — six axes]] déclare **trois économies** — ticks, mana, endurance — et dit qu'*« elles définissent des archétypes »*. Une Frappe lourde ou un Balayage qui coûtent du **mana** effacent la distinction entre le guerrier et le mage, et laissent `cout_endurance` sans emploi.
>
> **Décision retenue :** les modules de manuel coûtent **de l'endurance**, les modules de grimoire du **mana**, et les rares hybrides les deux. Ça donne enfin son rôle à l'endurance, ça rend *Le Sabre* jouable sans Volonté, et ça fait de l'action « attendre » (5 ticks, rend 20 d'endurance — [[Endurance]]) une décision de combat au lieu d'un bouton.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Modules]], [[Action-time à ticks]]
- **Alimente** : [[Décision — Pipeline de contenu]], [[Prototype de combat — spécification]], [[Vers la production]]
- **Voir aussi** : [[Six types de modules et assemblage]], [[Structure compétences-modules-slots]], [[Mana]], [[Endurance]], [[Armure par zone et constructions]], [[Pipeline de résolution du combat]], [[Jauge de chaîne Wu Xing]]
