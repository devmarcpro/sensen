---
aliases: ["F.2", "Annexe F.2", "Modules", "Catalogue des modules", "61 modules", "53 modules", "48 modules"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

> [!success] Transcrit dans le schéma le 2026-08-26
> Les 61 entrées passent du **format en prose du GDD** (antérieur au pivot tactique) au schéma réel de [[Vocabulaire des modules — six axes]]. Ce qui change : **`cout_ticks` sur les 61**, `forme` / `portée` / `cible` / `ligne de vue` explicites, durées **en ticks** au lieu de tours, et les **modules de manuel coûtent de l'endurance, plus du mana**. Audit du défaut et barèmes : [[Décision — Transcription du catalogue de modules]]. Transcription JSON : `godot/data/modules/*.json`.

Les **61 modules** du catalogue de départ — 44 de grimoire, 17 de manuel — dans le format que le code lit.

## Comment lire les colonnes

**Forme** · **Portée** en tuiles (`soi` = sur soi-même) · **LdV** = ligne de vue requise · **Coûts** : `t` = ticks (le tempo, [[Boucle de tick]]), `mana` ([[Mana]]), `end` = endurance ([[Endurance]]) · **Dés** = `power_base` ([[Pipeline de résolution du combat]]).

Les **modificateurs** et **déclencheurs** ne coûtent aucun tick : le surcoût est porté par le noyau qu'ils altèrent ([[Six types de modules et assemblage]]). L'**élément** est hérité du domaine ([[Domaines de grimoires et manuels]]) — Feu→Feu, Eau/Glace→Eau, Terre→Terre, Foudre et Vie→Bois, Métal→Métal, Arcane/Espace/Corruption→neutre ([[Wu Xing — cycles et vecteurs]]).

## Les trois économies

| | Ticks | Mana | Endurance |
|---|---|---|---|
| **Grimoire** (44) | ✅ | ✅ | — |
| **Manuel** (17) | ✅ | — | ✅ |

> **Décidé le 2026-08-26 :** un module d'arme ne coûte **jamais** de mana. C'est ce qui rend *Le Sabre* jouable sans Volonté, ce qui donne enfin son rôle à l'endurance, et ce qui transforme l'action « attendre » (5 ticks, rend 20 d'endurance) en vraie décision de combat au lieu d'un bouton.

## Grimoires — les 44 modules de sort

### Feu · élément Feu

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Projectile de feu** | effet | `ligne 1` | 1–6 | `ennemi` | oui | **10 t** · 8 mana | 2d6 | `degats` | lame de flamme qui file droit et perce la première cible |
| **Nova ardente** | effet | `carre 1` | soi | `toute_entite` | — | **18 t** · 18 mana | 3d6 | `degats` | éclate autour du lanceur, alliés compris |
| **Trait incendiaire** | effet | `cible_unique` | 1–5 | `ennemi` | oui | **8 t** · 12 mana | 1d4 | `degats` · `statut` | pose Brûlure 30 ticks |
| **Mains brûlantes** | effet | `cone 2` | 1–2 | `ennemi` | oui | **6 t** · 6 mana | 2d4 | `degats` | cône court, très bon marché en ticks |
| **Cœur de braise** | modificateur | — | — | — | — | 4 mana | — | — | le noyau suivant enflamme le sol qu'il touche, 50 ticks |

### Eau/Glace · élément Eau

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Trait de givre** | effet | `cible_unique` | 1–6 | `ennemi` | oui | **8 t** · 8 mana | 2d4 | `degats` · `statut` | pose Ralenti 20 ticks |
| **Prison de glace** | effet | `cible_unique` | 1–5 | `ennemi` | oui | **14 t** · 16 mana | — | `statut` | immobilise (1d4+1)x10 ticks — jet de Force pour briser ; compte dans le budget anti-stunlock |
| **Mur de glace** | effet | `ligne 3` | 1–4 | `tuile` | oui | **14 t** · 14 mana | — | `terrain` | 3 tuiles de glace réelles (friction 5), 100 ticks |
| **Soin des eaux** | effet | `cible_unique` | 1–4 | `allie` | oui | **10 t** · 12 mana | 2d6 | `soin` | soin à distance |
| **Brume** | effet | `carre 2` | 1–5 | `tuile` | — | **12 t** · 10 mana | — | `terrain` · `statut` | réduit la détection dans la zone, 100 ticks |

### Foudre · élément Bois

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Éclair** | effet | `cible_unique` | 1–7 | `ennemi` | oui | **10 t** · 10 mana | 2d8 | `degats` | multiplié par la conductivité électrique de l'armure de la cible |
| **Chaîne** | modificateur | — | — | — | — | 6 mana | — | — | liaison : le noyau suivant saute à 1d3 cibles proches |
| **Choc statique** | effet | `cible_unique` | 1–4 | `ennemi` | oui | **4 t** · 5 mana | 1d4 | `degats` · `tempo` | repousse le compteur d'action de la cible de 5 ticks — budget anti-stunlock |
| **Orage local** | effet | `carre 2` | 1–6 | `tuile` | — | **22 t** · 25 mana | 1d8 | `degats` · `terrain` | 1d8 par tranche de 10 ticks pendant 30 ticks |

### Terre · élément Terre

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Projectile rocheux** | effet | `cible_unique` | 1–6 | `ennemi` | oui | **9 t** · 8 mana | 2d6 | `degats` | contondant |
| **Pique de pierre** | effet | `tuile` | 1–5 | `ennemi` | — | **10 t** · 12 mana | 3d4 | `degats` | jaillit du sol — ignore le bouclier, pas de ligne de vue requise |
| **Peau de pierre** | effet | `soi` | soi | `soi` | — | **8 t** · 14 mana | — | `statut` | +4 de réduction plate sur TOUTES les zones, 50 ticks |
| **Séisme mineur** | effet | `carre 2` | 0–4 | `toute_entite` | — | **20 t** · 22 mana | 2d6 | `degats` · `deplacement` | jet d'Athlétisme ou chute — dégâts de chute (hauteur-2)x5 |
| **Façonnage** | effet | `tuile` | 1–3 | `tuile` | oui | **12 t** · 10 mana | — | `terrain` | élève ou abaisse une tuile d'un niveau |

### Vie · élément Bois

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Soin mineur** | effet | `cible_unique` | 1–4 | `allie` | oui | **8 t** · 8 mana | 3d4 | `soin` | le soin de base |
| **Régénération** | effet | `cible_unique` | 1–3 | `allie` | oui | **10 t** · 14 mana | 1d4 | `soin` · `statut` | 1d4 par tranche de 10 ticks pendant 50 ticks |
| **Croissance** | effet | `tuile` | 1–2 | `tuile` | oui | **15 t** · 12 mana | — | `terrain` | avance une culture d'un stade — hors combat |
| **Purge** | effet | `cible_unique` | 1–4 | `allie` | oui | **8 t** · 10 mana | — | `statut` | retire un statut négatif |
| **Lien vital** | effet | `cible_unique` | 1–5 | `allie` | oui | **10 t** · 16 mana | — | `soin` | transfère ses PV à un allié, 1:1 |

### Arcane · élément Neutre

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Trait de mana** | effet | `cible_unique` | 1–6 | `ennemi` | oui | **5 t** · 5 mana | 1d8 | `degats` | dégâts bruts, aucun élément — ne pose aucun segment de chaîne |
| **Bouclier arcanique** | effet | `soi` | soi | `soi` | — | **8 t** · 12 mana | 2d8 | `statut` | absorbe 2d8 dégâts jusqu'à épuisement |
| **Marque** | declencheur | — | — | — | — | 6 mana | — | — | le noyau suivant se déclenche sur la cible marquée au prochain impact |
| **Double incantation** | modificateur | — | — | — | — | 8 mana | — | — | liaison : répète le noyau suivant |
| **Concentration** | modificateur | — | — | — | — | 4 mana | — | — | +1 dé au noyau suivant |

### Espace · élément Neutre

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Pas éclipsé** | effet | `soi` | 1–5 | `soi` | oui | **6 t** · 10 mana | — | `deplacement` | téléportation courte, en ligne de vue |
| **Échange** | effet | `cible_unique` | 1–6 | `toute_entite` | oui | **8 t** · 14 mana | — | `deplacement` | échange sa position avec la cible |
| **Portée étendue** | modificateur | — | — | — | — | 5 mana | — | — | double la portée du noyau suivant |
| **Rappel** | effet | `soi` | soi | `soi` | — | **30 t** · 30 mana | — | `deplacement` | téléporte au lit ou au claim — cooldown 1 jour in-game, hors combat |
| **Poche dimensionnelle** | effet | `soi` | soi | `soi` | — | **12 t** · 20 mana | — | `statut` | +30 de capacité de poids pendant 10 minutes de temps monde |

### Corruption · élément Neutre

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Sang pour puissance** | modificateur | — | — | — | — | 0 | — | — | le noyau suivant coûte des PV au lieu du mana, 2 PV pour 1 mana |
| **Drain** | effet | `cible_unique` | 1–5 | `ennemi` | oui | **10 t** · 12 mana | 2d4 | `degats` · `soin` | soigne la moitié des dégâts infligés |
| **Terreur** | effet | `cible_unique` | 1–5 | `ennemi` | oui | **12 t** · 14 mana | — | `statut` | jet de Volonté ou la cible fuit (1d4)x10 ticks — budget anti-stunlock |
| **Contagion** | modificateur | — | — | — | — | 8 mana | — | — | les statuts du noyau suivant se propagent aux ennemis adjacents |
| **Appel corrompu** | effet | `tuile` | 1–3 | `tuile` | oui | **25 t** · 28 mana | — | `invocation` | invoque une créature corrompue alliée temporaire — occupe une tuile |

### Métal · élément Métal

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Lame spectrale** | effet | `ligne 4` | 1–4 | `ennemi` | oui | **9 t** · 8 mana | 2d6 | `degats` | lame invoquée qui traverse la ligne |
| **Perforation** | effet | `cible_unique` | 1–3 | `ennemi` | oui | **10 t** · 12 mana | 2d8 | `degats` | ignore intégralement la réduction d'armure de zone |
| **Pluie d'aiguilles** | effet | `carre 2` | 1–6 | `toute_entite` | — | **16 t** · 18 mana | 2d4 | `degats` | friendly fire intégral |
| **Mur de lames** | effet | `tuile` | 1–4 | `tuile` | oui | **14 t** · 14 mana | 2d4 | `invocation` | tuile hérissée 50 ticks — bloque le passage, blesse au contact |
| **Affûtage** | modificateur | — | — | — | — | 5 mana | — | — | +1 dé au noyau suivant et le rend perforant |

## Manuels — les 17 modules d'arme

### Frappes

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Frappe lourde** | effet | `cible_unique` | 1–1.5 | `ennemi` | oui | **8 t** · 12 end | 1d6 | `degats` | s'ajoute aux dégâts d'arme |
| **Fente** | effet | `cible_unique` | 1–2 | `ennemi` | oui | **6 t** · 10 end | — | `degats` · `deplacement` | attaque et avance d'une tuile |
| **Balayage** | effet | `anneau 1` | soi | `ennemi` | — | **14 t** · 18 end | — | `degats` | touche toutes les cibles adjacentes — friendly fire |
| **Brise-garde** | effet | `cible_unique` | 1–1.5 | `ennemi` | oui | **10 t** · 14 end | — | `statut` | la cible perd 50 % de sa réduction d'armure de zone, 20 ticks |
| **Exécution** | effet | `cible_unique` | 1–1.5 | `ennemi` | oui | **12 t** · 20 end | 2d6 | `degats` | condition : pv_cible < 30 % |

### Postures

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Garde de fer** | effet | `soi` | soi | `soi` | — | **4 t** · 10 end | — | `statut` | +5 de réduction plate sur toutes les zones tant que la posture tient — entretien 2 endurance / 10 ticks |
| **Posture du vent** | effet | `soi` | soi | `soi` | — | **4 t** · 10 end | — | `statut` | +0.5 attaque / 10 ticks, -3 de réduction plate — entretien 2 endurance / 10 ticks |
| **Ancrage** | effet | `soi` | soi | `soi` | — | **4 t** · 8 end | — | `statut` | immunité aux projections, aux reculs et à la saisie |
| **Duelliste** | effet | `cible_unique` | 1–6 | `ennemi` | oui | **5 t** · 12 end | — | `statut` | contre la cible désignée : tes attaques coûtent 1 tick de moins et ignorent 2 points de réduction |

### Techniques

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Pas de côté** | effet | `soi` | 1–2 | `soi` | — | **4 t** · 8 end | — | `deplacement` | esquive-déplacement de 2 tuiles |
| **Contre** | declencheur | — | — | — | — | 12 end | — | — | riposte automatique au prochain coup esquivé |
| **Charge** | effet | `chemin 4` | 1–4 | `ennemi` | oui | **10 t** · 16 end | 1d6 | `degats` · `deplacement` | rue sur 4 tuiles, projette la cible |
| **Désarmement** | effet | `cible_unique` | 1–1.5 | `ennemi` | oui | **10 t** · 16 end | — | `statut` | jet opposé — l'arme de la cible tombe sur sa tuile |

### Maîtrise

| Module | Type | Forme | Portée | Cible | LdV | Coûts | Dés | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|---|---|
| **Coups jumeaux** | modificateur | — | — | — | — | 12 end | — | — | la frappe suivante frappe deux fois, chacune à -1 dé |
| **Allonge** | modificateur | — | — | — | — | 6 end | — | — | +1 tuile de portée sur la frappe suivante |
| **Économie de geste** | modificateur | — | — | — | — | **-2 t** · 5 end | — | — | la frappe suivante coûte 2 ticks de moins |
| **Impact** | modificateur | — | — | — | — | 8 end | — | — | la frappe suivante projette d'1d3 tuiles |

## Ce qui a été réécrit

Quatre entrées employaient des mécaniques supprimées par le pivot tactique :

| Module | Avant (GDD) | Maintenant |
|---|---|---|
| **Peau de pierre** | « +2d4 dés d'armure 5 tours » | **+4 de réduction plate** sur toutes les zones, **50 ticks** ([[Armure par zone et constructions]]) |
| **Brise-garde** | « la cible perd ses dés d'armure 2 tours » | la cible perd **50 % de sa réduction de zone**, **20 ticks** |
| **Garde de fer** | « +1d6 armure tant que la posture tient » | **+5 de réduction plate**, entretien **2 endurance / 10 ticks** |
| **Duelliste** | « +2 toucher contre une cible désignée » | contre la cible désignée : **−1 tick par attaque** et **ignore 2 points de réduction** ([[Pipeline de résolution du combat]] : le jet de toucher d'E.3 est superseded) |

**Conversion des durées :** l'étalon est **1 tour du GDD = 10 ticks** (une épée frappe 2 fois par 10 ticks). « brûlure 3 tours » devient `30 ticks`.

**Trois modules entrent dans le budget anti-stunlock** ([[Statuts de contrôle et anti-stunlock]]) : Prison de glace, Terreur et Choc statique — ce dernier porte l'effet `tempo`, et un retard est un contrôle dur déguisé.

**Schéma de données :** [[Vocabulaire des modules — six axes]]. **Assemblage :** [[Six types de modules et assemblage]]. **Acquisition :** [[Grimoires et manuels]]. **Slots :** [[Structure compétences-modules-slots]].

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Domaines de grimoires et manuels]], [[Six types de modules et assemblage]]
- **Alimente** : [[Structure compétences-modules-slots]], [[Familles de capacités de la grille]], [[Statuts]], [[Prototype de combat — spécification]]
- **Voir aussi** : [[Décision — Transcription du catalogue de modules]], [[Grimoires et manuels]], [[Mana]], [[Endurance]], [[Boucle de tick]], [[Armure par zone et constructions]], [[Wu Xing — cycles et vecteurs]], [[Ouvert — Modules du domaine Métal]]
