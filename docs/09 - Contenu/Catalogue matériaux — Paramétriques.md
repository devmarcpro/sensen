---
aliases: ["F.1 Paramétriques", "Matériaux paramétriques", "Parties de créatures", "Végétaux paramétriques"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Des gabarits instanciés depuis une source plutôt que des entrées fixes — une définition couvre toutes les variantes.

**Végétaux paramétriques (2 gabarits × 40 essences) — dérivés automatiquement de chaque arbre ([[Schéma matériau]])**

| Gabarit | Dur | Den | Val | Fla | Iso | Flo | Éla | Notes |
|---|--|--|--|--|--|--|--|---|
| Feuilles de [essence] | 1 | 1 | 1 | 80 | 40 | 90 | 40 | couleur dérivée de l'essence ; compost/fourrage ; bloc décoratif |
| Pousse de [essence] | 1 | 1 | 3 | 60 | 30 | 85 | 30 | replantable → **sylviculture** : l'arbre repousse (vitesse selon essence, ×2 pour peuplier/eucalyptus) |

**Parties de créatures (6 gabarits × créatures [[Créatures]]) — drops de mobs, paramétriques ([[Schéma matériau]]) ; ingrédients d'alchimie ([[Cuisine et alchimie]]) et de craft**

| Gabarit | Usage principal | Dérivation |
|---|---|---|
| Viande de [créature] | cuisine ([[Cuisine et alchimie]]) | bonus de potentiel ∝ stats de la source ([[Nourriture, potentiel et potions]]) |
| Peau de [créature] | cuir (tannage, catégorie fibre), alchimie | dureté/isolation ∝ Endurance de la source |
| Os de [créature] | outils/armes primitifs, alchimie, engrais | dureté ∝ Force de la source |
| Dent/croc de [créature] | pointes de flèches, alchimie, bijoux | dureté ∝ niveau de combat |
| Griffe de [créature] | alchimie (Force/Dextérité), outils | dureté ∝ Dextérité |
| Œil de [créature] | alchimie (Perception/vision) | valeur ∝ Perception |

**Principe ([[Schéma matériau]]) :** `"parametric": {"source": "creature"|"tree"}`. *Une seule définition couvre toutes les variantes — les 40 essences ont leurs feuilles sans 40 entrées ; la couleur d'une variante = couleur de la source décalée déterministiquement (pas de collision avec la palette [[Palette de couleurs des matériaux]], vérifiée au boot).*

**Formule de viande ([[Nourriture, potentiel et potions]]) :**
```
VIANDE (paramétrique) : bonus_potentiel(stat) =
         stat_source_creature / 10  (arrondi, max 8 par stat)
  ex. ours brun For 14 → viande : +1.4 → +1 potentiel Force par unité
  cuisinée dans un plat (multiplié par nutrition/qualité).
```

**Exception Wu Xing ([[Wu Xing hors combat]]) :** l'**os** porte un vecteur Bois/Terre (surcharge `wuxing`).

**Constructions d'armure ([[Armure par zone et constructions]]) :** Cuir (peaux paramétriques) · Écailles (métal, os, écailles) · Plaque (lingots, **os massif**).

**Boucle de chasse ([[Cuisine et alchimie]]) :** *la chasse d'une créature précise pour sa viande/ses parties devient un objectif en soi.*

## Liens
- **Dépend de** : [[Schéma matériau]], [[Schéma créature]], [[Catalogue matériaux — Bois]]
- **Alimente** : [[Cuisine et alchimie]], [[Nourriture, potentiel et potions]], [[Armure par zone et constructions]], [[Potions]]
- **Voir aussi** : [[Créatures]], [[Catalogue matériaux — Végétaux et fibres]], [[Palette de couleurs des matériaux]], [[Wu Xing hors combat]], [[Plantes]]
