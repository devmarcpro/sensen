---
aliases: ["Wu Xing hors combat", "Wu Xing transversal", "Vecteur de lieu", "Élément du lieu"]
tags: [combat, wuxing, monde, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le Wu Xing comme grammaire transversale : l'assiette, le lieu, les matériaux — pas seulement le combat.

**Au-delà du combat (le Wu Xing comme grammaire transversale) :**

- **Alchimie et cuisine ([[Cuisine et alchimie]])** : chaque ingrédient porte une affinité élémentaire (dérivée de sa catégorie/nature, surchargée en données) ; un **plat équilibré sur les cinq éléments** gagne un bonus de nutrition et de potentiel (**+20 %**) — l'assiette harmonieuse du daoïsme, mécanisée.
- **Le lieu** : chaque position porte un **vecteur élémentaire dérivé des couches de bruit** (jamais de l'étiquette de biome) — fertilité×humidité→Bois, température extrême/volcanisme→Feu, richesse minérale→Métal, humidité haute→Eau, base+profondeur→Terre. Fonction pure évaluée à la demande, comme la météo : coût nul, transitions douces, valable partout y compris en donjon. Lancer un module de l'élément dominant du lieu coûte **−15 %** de mana ; l'élément qu'il domine, **+15 %**.
- **Les matériaux** portent un vecteur **dérivé de leur catégorie** (métal→Métal, bois/fibre→Bois, roche/terre→Terre, liquide/glace→Eau, forte flammabilité→Feu), avec un champ `wuxing` optionnel pour les seules exceptions où la catégorie ment (obsidienne Terre/Feu, ambre Bois/Terre, charbon Feu, os Bois/Terre). Deux règles générales : **plus la transformation est violente, plus le Feu entre** (fonte, trempe, cuisson) ; **plus un matériau est composite, plus son vecteur s'aplatit** — d'où des matériaux industriels statistiquement forts mais élémentairement muets ([[Palier industriel]]).
- Extensions futures naturelles (non incluses au lancement) : saisons alignées sur les éléments (si [[Météo]] les active un jour — voir [[Ouvert — Saisons]]), enchantements élémentaires ([[Effets d'équipement passifs]]).

**Blocs canoniques (A.4.6) :**

```
COÛT DE MANA PAR LIEU : élément du module == dominant du lieu
  (vecteur dérivé des couches de bruit, 5.2) : x0.85 ;
  élément dominé par celui du lieu : x1.15.

CUISINE (7.7) : un plat couvrant les 5 éléments : nutrition et
  potentiel x1.2 — l'équilibre daoïste de l'assiette, mécanisé.
```

**Condition de module associée ([[Vocabulaire des modules — six axes]]) :** `vecteur_de_lieu` est l'une des conditions positionnelles disponibles.

**Contenu à produire :** [[Ouvert — Surcharges wuxing des matériaux]], [[Ouvert — Affinités élémentaires de cuisine]].

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Génération par couches de bruit]], [[Matériaux — 13 stats]]
- **Alimente** : [[Cuisine et alchimie]], [[Mana]], [[Craft compositionnel]], [[Palier industriel]]
- **Voir aussi** : [[Biomes — schéma]], [[Météo]], [[Vocabulaire des modules — six axes]], [[Ouvert — Surcharges wuxing des matériaux]], [[Ouvert — Affinités élémentaires de cuisine]], [[Ouvert — Saisons]]
