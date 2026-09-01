---
aliases: ["B.5", "Annexe B.5", "Schéma créature", "data/creatures", "Fiche PNJ"]
tags: [êtres, données, schéma, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Le format de données unique de tout être vivant du jeu — monstre comme marchand.

`data/creatures/*.json` :

```json
{
  "id": "villageois_humain",
  "name_key": "creature.villageois_humain.name",
  "skeleton_template": "humanoide",
  "parts_pool": {
    "tete":  [1, 4, 18, 32],
    "torse": [1, 42],
    "bras":  [1, 3],
    "jambes": [6, 7]
  },
  "race": "humain",
  "classe": "forgeron",
  "fonction": "artisan",
  "base_stats": { "sante": 40, "force": 8, "volonte": 6, "vitesse": 10 },
  "equip_slots": "humanoide_standard",
  "inventory_table": "loot_villageois",
  "ai_profile": "civil",
  "jobs_compatible": ["fermier", "vendeur", "garde"],
  "housing_default": "normal",
  "recruitable": { "method": "relation", "threshold": 60 },
  "leadership_role": null,
  "succession_rule": null,
  "rare_chance": 0.02,
  "elements": null,
  "tags": ["humanoide", "civil", "commerce_possible"]
}
```

- `recruitable.method` : `"relation"` (seuil), `"dressage"` (jet de compétence), `"quete"` (id de gabarit), ou `"jamais"`.
- `jobs_compatible` : postes de travail assignables ([[Population et exploitation]]) ; `housing_default` : statut de logement initial ([[Habitat des PNJ]]), modifiable par le joueur (y compris → `"betail"`).
- `leadership_role` (instance uniquement, ex. `"roi_royaume_x"`, `"maitre_guilde_guerriers"`) et `succession_rule` (`"heir"` ou `"next_in_rank"`, [[Familles et succession]]) : définis sur les PNJ uniques, `null` pour la population générique.
- Liens familiaux (instance) : `"family": {"parent_of": [...], "child_of": "...", "spouse": "..."}` — pilote la succession ([[Familles et succession]]) et la démographie ([[Âge des PNJ]]).
- `rare_chance` (0 pour civils/uniques/bétail) : système de variantes rares ([[Monstres rares]]).
- **Identité (instance, humanoïdes civils/uniques uniquement) :** `"prenom"`, `"nom_famille"`, `"titre"` (optionnel, PNJ à `leadership_role`) — générés à l'instanciation par le système de noms culturels ([[Noms culturels]]/[[Génération de noms]]), jamais pour les bêtes/monstres (une variante rare garde son épithète, [[Monstres rares]], pas un nom propre).
- Un monstre utilise exactement le même schéma (`ai_profile: "hostile"`, `recruitable.method: "dressage"`...).
- Les PNJ ont leurs propres compétences qui **progressent à l'usage comme le joueur** (instance ≠ définition : l'état courant des skills vit dans la sauvegarde).

**Champ `elements` ([[Wu Xing — cycles et vecteurs]]) :** l'alignement élémentaire d'une créature est dérivé de ce champ ou de ses tags.

**Champ `equip_slots` ([[Équipement — 14 slots]]) :** emplacements par morphologie — quadrupède = tête, torse, selle, amulette, 2 accessoires · volant = tête, torse, amulette, 2 accessoires · amorphe = amulette, 2 accessoires.

**Les trois axes ([[Les trois axes — race, classe, fonction]]) :** `race` (qui il est — **absorbe l'ancien champ `espece`**, un loup a pour race « loup ») · `classe` (ce qu'il sait, porteuse du talent — [[Talents de classe]] ; absente chez les êtres sans `esprit` suffisant) · `fonction` (ce qu'il fait — [[Fonctions]] ; **absorbe `jobs_compatible` et `leadership_role`**).

**Extension Annexe H — les blocs et le génome ([[Blocs de l'être]]) :** le schéma ci-dessus est la forme « PNJ » du schéma unique. S'y ajoutent :
- `role` : `sauvage` | `apprivoisé` | `résident` | `garde` | `bétail` ([[Rôles de l'être]]) — **absorbe et généralise** `housing_default` et complète `recruitable`.
- `genome` : dictionnaire de loci, **dont la forme est déclarée par l'espèce** ([[Loci — les dix types]]) — absent pour les êtres sans hérédité, auquel cas `parts_pool` gouverne l'apparence ([[Apparence — données et équipement]]).
- `repro` : `{ moteur, conditions, portée, coûts }` ([[Conditions de reproduction]]) — absent pour les êtres non reproductibles.
- `esprit` : `{ intelligence, tempérament, dressabilité }` — ce qui décide des transitions de rôle.

**Aucun système ne teste l'espèce : il teste la présence du bloc** ([[Tests de conformité — élevage]], test 6).

**Matériaux paramétriques dérivés ([[Schéma matériau]], [[Catalogue matériaux — Paramétriques]]) :** Viande de X, Peau de X, Os de X, Dent, Griffe, Œil — stats dérivées de la fiche de la créature.

> [!success] Décidé le 2026-08-26 — forme des fiches du prototype (`data/creatures/`)
> Les fiches suivent la forme à blocs de [[Blocs de l'être]] : `corps.stats` porte les **six stats** de [[Stats de personnage]] (l'ancien `base_stats {sante, force, volonte, vitesse}` est retiré du template : la santé est **dérivée**, `sante_max = 20 + Endurance × 4`, la vitesse vient de l'arme et du dénivelé). S'ajoutent, tous génériques : `equipement` (ids d'objets portés — un bandit porte son épée comme le joueur), `ratelier` (armes de rechange, swap 4 ticks), `actions` (ids de [[Actions des créatures]]), `chain_gauge`, `teinte` (couleur du billboard placeholder — rendu, pas gameplay). Le **contrôle n'est pas dans la fiche** : c'est l'arène (ou la partie) qui dit qui est `joueur` et qui est `ia` à l'instanciation ([[Contraintes permanentes]], règle 5).

> [!success] Décidé et codé le 2026-08-28 — étape 9.A, la forme unique de la fiche
> **La forme à blocs codée fait foi** (contradiction tranchée) ; les blocs sociaux du schéma B.5 s'y ajoutent, tous optionnels : `role` (résident, garde…), `fonction` (id de `data/functions/`), `social {culture, relations{}}`, `agenda {metier}`, `recruitable {method, threshold}`, `esprit {intelligence, temperament, dressabilite}`, `genre` (m/f, ou tiré), `inventaire_marchand` (bases d'objets en stock, tag `commerce_possible`). Le nom propre est **tiré à l'instanciation** ([[Génération de noms]]) et enregistré comme clé de traduction (`pnj.<id>.name`), si bien que tout ce qui affiche `name_key` affiche le nom. `parts_pool`, `jobs_compatible`, `housing_default`, `equip_slots`, `leadership_role` sont retirés du vocabulaire (absorbés par `fonction`, `agenda` et le rig).

> [!success] Codé le 2026-09-01 — `drops_chasse` : ce qu'un chasseur peut tirer d'une bête (designer)
> « du coup dans la fiche espèce il faut un champ pour les drops de chasseurs ». La fiche sépare désormais deux choses qui n'ont rien à voir : **`depouille`**, ce qui tombe toujours — la viande, le miel —, et **`drops_chasse`**, les pièces qui demandent un **jet de Chasseur** : peau, os, dents, griffes, yeux, fourrure. Chaque pièce est tirée séparément contre `dd_base + PV_max / pv_par_point` ; une réussite large en rend plusieurs (`marge_par_piece`, plafonné). Les vingt-deux bêtes à peau ont vu leurs pièces migrer de `depouille` vers `drops_chasse` : tuer un ours sans savoir chasser rend maintenant de la viande, et rien d'autre.


## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Data-driven design]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[IA des créatures]], [[Apprivoisement et recrutement]], [[Monstres rares]], [[Familles et succession]], [[Créatures]], [[Catalogue matériaux — Paramétriques]]
- **Voir aussi** : [[Habitat des PNJ]], [[Population et exploitation]], [[Noms culturels]], [[Équipement — 14 slots]], [[Wu Xing — cycles et vecteurs]], [[Sauvegarde]], [[Localisation]]
