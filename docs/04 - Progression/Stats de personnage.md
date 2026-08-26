---
aliases: ["C.1", "Annexe C.1", "Stats", "Six stats", "Stats de personnage"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

Les six stats du personnage et ce que chacune pilote.

| Stat | Effet principal |
|---|---|
| Force | Dégâts mêlée, poids transportable |
| Dextérité | Vitesse d'attaque, précision |
| Endurance | Santé max, résistance |
| Volonté | Mana max, résistance mentale |
| Perception | Détection (POI, minerais), portée |
| Charisme | Prix, relations PNJ |

Création : 30 points à répartir (base 5 par stat, max 15 à la création), + choix de race, classe, apparence (parties du corps, [[Schéma unifié créature-PNJ]]).

**Formules qui les consomment directement :**
- `mana_max = 20 + (Volonté × 3) + (N_meditation × 2)` ([[Mana]])
- `capacite = 30 + Force × 5` ([[Armures et poids porté]])
- `places_escorte = 1 + floor(Charisme / 5) + floor(N_leadership / 10)` ([[Compagnons]])
- Souffle sous l'eau : `30 s + Endurance × 2` ([[Eau et liquides]])
- Jets de dégâts : `+ For/4` (mêlée) ou `+ Dex/4` (distance) ([[Pipeline de résolution du combat]])
- `facteur_reputation` de prix passe par le Charisme ([[Prix suggéré]])

**Chaque stat a son potentiel** ([[Potentiel]]).

**Potions de stat :** +3 stat pendant 10 min ([[Potions]]).

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Mana]], [[Armures et poids porté]], [[Compagnons]], [[Potentiel]], [[Pipeline de résolution du combat]]
- **Voir aussi** : [[Races]], [[Classes]], [[Astrologie — cycle sexagésimal]], [[Compétences — liste]], [[Effets d'équipement types]], [[Potions]]
