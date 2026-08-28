---
aliases: ["F.8", "Annexe F.8", "Plantes", "22 plantes", "Cultures", "Herbes"]
tags: [contenu, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 10
---

Les 22 plantes non-arbres — réelles, récolte Herboristerie/Agriculture.

**Cultures (8, cultivables en champs [[Agriculture et élevage]]) :** Blé (pain), Orge (bière/soupe), Carotte, Pomme de terre, Chou, Oignon, Citrouille, Tomate — chaque culture a nutrition + bonus de potentiel propres (données `data/plants/`).

**Buissons & vignes (4) :** Framboisier, Myrtillier, Vigne (raisin/vin via alambic), Houblon (bière).

**Herbes médicinales/alchimiques (6) :** Camomille (potions de calme/sommeil), Menthe (fraîcheur — résistance chaleur), Sauge (mana), Achillée (soin/saignement), Ortie (fibres + potions de résistance), Belladone (poisons — **illégale dans certains royaumes**, [[Lois et infractions]] !).

**Champignons (2) :** Champignon des prés (comestible), Amanite (toxique — poison d'alchimie).

**Décoratives (2) :** Fleurs sauvages (teintures + humeur des pièces), Roseau (vannerie, chaume, papier).

**Ingrédients d'alchimie ([[Cuisine et alchimie]]) :** les plantes, avec les parties de créatures ([[Catalogue matériaux — Paramétriques]]), orientent l'effet de la potion.

**Végétation par biome ([[Biomes — schéma]]) :** champ `vegetation` avec densités par entrée.

**Récolte ([[Récolte]]) :** outil faucille, compétence Herboristerie ([[Catégories de matériaux]]).

**Croissance ([[Simulation du monde — performance]]) :** timer wheel — 10 000 cultures plantées = coût nul entre deux échéances. Le module **Croissance** ([[Modules]]) accélère une culture d'1 stade.

**Météo ([[Météo]]) :** pluie → +15 % vitesse de pousse ; canicule → flétrissement sans arrosage manuel.

> [!success] Codé le 2026-08-28 — les 22 plantes
> Les 14 non-cultures rejoignent `data/plants/` (catégories `buisson`, `herbe`, `champignon`, `decorative`) et `data/items/` (consommables crus, tags `ingredient` + catégorie ; **Amanite** et **Belladone** empoisonnent qui les mange : statut `poison`). Décision : **toutes se plantent dans un champ** comme les cultures (`_planter` ne distingue pas) — les buissons poussent en 12 jours, les herbes en 3, les champignons en 2, les décoratives en 4 ; la **cueillette sauvage par biome** (champ `vegetation`) attend. Trois potions de plantes à l'alambic : **Achillée** → *potion de soin* (2d6 PV), **Sauge** → *potion de mana* (+20), **Fleurs sauvages** → *potion de charisme* (+3, forte à haute qualité) ; les neuf autres potions de [[Potions]] attendent leurs statuts (résistances, vision nocturne, sommeil).

## Liens
- **Dépend de** : [[Agriculture et élevage]], [[Catégories de matériaux]], [[Biomes — schéma]]
- **Alimente** : [[Cuisine et alchimie]], [[Potions]], [[Nourriture]], [[Catalogue matériaux — Végétaux et fibres]]
- **Voir aussi** : [[Lois et infractions]], [[Récolte]], [[Météo]], [[Simulation du monde — performance]], [[Modules]], [[Catalogue matériaux — Paramétriques]]
