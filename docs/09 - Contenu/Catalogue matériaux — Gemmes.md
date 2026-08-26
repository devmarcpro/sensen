---
aliases: ["F.1 Gemmes", "Gemmes", "Cristaux", "Catalogue gemmes"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 3
---

Les 10 gemmes — chacune a un rôle, le choix n'est plus esthétique mais tactique.

**Gemmes & cristaux (10) — outil : pioche, compétence Minage, transformation : Table d'enchantement**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri | Notes |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|---|
| Quartz | 20 | 9 | 8 | 45 | 0 | 15 | 25 | 3 | 10 | 0 | 70 | 2 | 30 | générique abordable |
| Améthyste | 22 | 9 | 25 | 75 | 0 | 15 | 45 | 3 | 25 | 0 | 68 | 2 | 30 | équilibre mana/foudre |
| Topaze | 28 | 9 | 30 | 60 | 0 | 10 | 70 | 3 | 14 | 0 | 66 | 2 | 30 | LA gemme de foudre |
| Grenat | 24 | 10 | 18 | 55 | 0 | 12 | 24 | 3 | 10 | 0 | 58 | 2 | 30 | le "budget" du mage |
| Opale | 12 | 7 | 45 | 92 | 0 | 18 | 22 | 4 | 45 | 0 | 55 | 5 | 32 | reine du mana, FRAGILE |
| Jade | 26 | 10 | 38 | 50 | 0 | 35 | 15 | 3 | 8 | 0 | 40 | 25 | 34 | la plus tenace (élastique) |
| Rubis | 27 | 9 | 40 | 78 | 0 | 0 | 25 | 3 | 22 | 0 | 62 | 2 | 30 | affinité feu (iso 0) |
| Saphir | 27 | 9 | 40 | 78 | 0 | 80 | 28 | 3 | 12 | 0 | 66 | 2 | 30 | affinité froid (iso 80) |
| Émeraude | 24 | 9 | 50 | 82 | 0 | 15 | 26 | 3 | 12 | 0 | 64 | 2 | 30 | mana haut, la + précieuse hors diamant |
| Diamant | 40 | 9 | 80 | 55 | 0 | 15 | 12 | 3 | 20 | 0 | 85 | 1 | 28 | dureté inégalée, mana moyen |

*(Colonne "Notes" ajoutée : chaque gemme a désormais un rôle — le choix n'est plus esthétique mais tactique.)*

*(La conductivité de mana des gemmes/métaux nobles est l'interprétation magique du monde — les matériaux restent réels, c'est leur usage qui est fantastique.)*

**Choix de la gemme du bâton ([[Application des stats de matériau]]) :** `cout_effectif *= (1 - conductivite_mana_arme / 140)` — *30 points d'écart entre deux gemmes ≈ 21 % de coût, le choix de la gemme du bâton devient structurant*. D'où Opale (92) vs Jade (50).

**Profils assumés ([[Application des stats de matériau]]) :** *l'opale règne sur le mana mais casse* (Dur 12), *le jade tient par son élasticité* (Éla 25) — exemples canoniques du principe de profils.

**Taille et sertissage ([[Loot — affixes, gemmes et rareté]]) :**
- Rubis→Feu · Saphir→Eau · Émeraude→Bois · Topaze→Terre · **Onyx**→Métal : +[1-3] dégâts élémentaires OU +[4-10] domaine
- Diamant : +[0.03-0.08] qualité · Améthyste : mana ou Méditation · Grenat : PV ou Force/Endurance · Opale : durée des statuts ou Volonté/Charisme · Ambre ([[Catalogue matériaux — Minéraux]]) : endurance ou compétence physique
- **Taille en affinité** : ajout au vecteur Wu Xing selon la qualité (misérable +0.04 → mythique +0.28) — seule voie par laquelle l'atelier touche à l'identité élémentaire.

> *Note : l'**Onyx** est cité dans la table de sertissage de [[Loot — affixes, gemmes et rareté]] (Onyx→Métal) mais n'apparaît pas dans la table F.1 des 10 gemmes ci-dessus ni dans la palette F.1.1. Signalé tel quel — à ajouter au catalogue.*

**Résistance au feu ([[Application des stats de matériau]]) :** *le saphir contre le feu* (Iso 80) est décisif.

**Placement ([[Minerais par profondeur]]) :** quartz (−30→−120) · améthyste, topaze, grenat (−80→−220) · opale, jade, rubis, saphir, émeraude (−160→−320) · diamant dans la kimberlite (−280→fond).

**Transformation ([[Stations de transformation]]) :** Table d'enchantement — gemmes → gemmes taillées.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Modificateurs d'affinité]], [[Mana]], [[Stations de transformation]]
- **Voir aussi** : [[Application des stats de matériau]], [[Minerais par profondeur]], [[Palette de couleurs des matériaux]], [[Catalogue matériaux — Roches]], [[Ouvert — Fourchettes des gemmes]]
