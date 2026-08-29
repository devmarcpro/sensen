---
aliases: ["F.5", "Annexe F.5", "Nourriture", "Consommables", "18 consommables"]
tags: [contenu, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 7
---

Les 18 nourritures et consommables de départ.

Pain (+20 faim) · Ragoût (+35 faim, +5 PV) · Viande grillée (+30 faim) · Viande crue (+15 faim, 20 % infection) · Poisson grillé (+25 faim) · Baies (+8 faim) · Champignon bleu (+5 faim, +10 mana) · Fruit de mana (+10 faim, +25 mana) · Ration de voyage (+25 faim, ne périme pas) · Ration moisie (+15 faim, 30 % poison) · Fiole de soin (2d6 PV) · Grande fiole de soin (4d6 PV) · Essence de mana (+30 mana instantané) · Antidote (purge poison) · Bandage (stoppe saignement, +1d4 PV) · Élixir de hâte (statut Hâte 10 tours) · Huile d'arme (prochain combat : +1d4 feu par coup) · Torche (item main : luminosité 70, consommée en 10 min)

**Manger cru ([[Nourriture, potentiel et potions]]) :** 50 % de la nutrition, aucun bonus de potentiel, risque d'infection — *cuisiner est toujours mieux*.

**Statuts liés ([[Statuts]]) :** Infection (viande crue), Poison (ration moisie), Hâte (élixir), Saignement (bandage).

**Nutrition et faim ([[Faim]]) :** manger restaure selon l'aliment (valeur nutritive en données). **La nutrition est le multiplicateur des bonus de potentiel** ([[Cuisine et alchimie]]).

**Torche ([[Équipement — 14 slots]]) :** occupe un slot de main (luminosité 70 — [[Application des stats de matériau]] : un objet lumineux porté éclaire mais augmente la détection par les ennemis).

**Plats cuisinés :** les recettes de cuisine combinent des ingrédients en plats, dont les bonus de potentiel dérivent des ingrédients — voir [[Cuisine et alchimie]] et [[Plantes]].

> [!success] Codé le 2026-08-28 — les 18 consommables en `data/items/` (type `consommable`)
> Champs : `nutrition` (faim rendue), `soin_des`, `mana`, `statut` + `statut_ticks` (Hâte, Saignement stoppé…), `risque` (Infection 20 % pour la viande crue, Poison 30 % pour la ration moisie), `potentiel` (bonus par stat, les plats seulement — [[Nourriture, potentiel et potions]]), `cru` (50 % de nutrition, aucun potentiel). La torche reste un objet de main (luminosité) sans durée. **Sources** : la viande crue est la **dépouille** des animaux (`depouille` dans `data/creatures/` : loup, sanglier, aigle, scorpion — les viandes paramétriques attendent l'étape 10), le reste tombe des coffres de donjon (`loot_rules.bases_consommables`). Plats à la **Cuisine** (`data/recipes/plat_*`) : viande grillée, ragoût, ration de voyage, avec une **qualité A.3** sur la compétence Cuisine qui multiplie le potentiel (formule de [[Nourriture, potentiel et potions]] : `potentiel × nutrition/100 × qualité`).

> [!success] Codé le 2026-08-29 — l'huile d'arme faisait vraiment quelque chose (bug)
> Trou trouvé par un audit des données : boire l'huile posait bien le drapeau `huile_feu`, et l'engagement écrivait `e.degats_element_bonus = {"feu": "1d4"}` — **que rien ne lisait jamais**. Le coup d'arme ajoute désormais ce jet à ses dégâts plats (à côté des gemmes, `degats_element`), et le bonus est **effacé à la fin du combat** : « prochain combat » veut dire un combat, pas la partie entière. Le journal l'annonce au premier coup enduit.

## Liens
- **Dépend de** : [[Faim]], [[Cuisine et alchimie]], [[Nourriture, potentiel et potions]]
- **Alimente** : [[Statuts]], [[Potentiel]], [[Faim des PNJ]]
- **Voir aussi** : [[Plantes]], [[Potions]], [[Catalogue matériaux — Paramétriques]], [[Meubles]], [[Équipement — 14 slots]], [[Application des stats de matériau]]
