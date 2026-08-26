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

**Extension Annexe H — les blocs et le génome ([[Blocs de l'être]]) :** le schéma ci-dessus est la forme « PNJ » du schéma unique. S'y ajoutent :
- `role` : `sauvage` | `apprivoisé` | `résident` | `garde` | `bétail` ([[Rôles de l'être]]) — **absorbe et généralise** `housing_default` et complète `recruitable`.
- `genome` : dictionnaire de loci, **dont la forme est déclarée par l'espèce** ([[Loci — les dix types]]) — absent pour les êtres sans hérédité, auquel cas `parts_pool` gouverne l'apparence ([[Apparence — données et équipement]]).
- `repro` : `{ moteur, conditions, portée, coûts }` ([[Conditions de reproduction]]) — absent pour les êtres non reproductibles.
- `esprit` : `{ intelligence, tempérament, dressabilité }` — ce qui décide des transitions de rôle.

**Aucun système ne teste l'espèce : il teste la présence du bloc** ([[Tests de conformité — élevage]], test 6).

**Matériaux paramétriques dérivés ([[Schéma matériau]], [[Catalogue matériaux — Paramétriques]]) :** Viande de X, Peau de X, Os de X, Dent, Griffe, Œil — stats dérivées de la fiche de la créature.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Data-driven design]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[IA des créatures]], [[Apprivoisement et recrutement]], [[Monstres rares]], [[Familles et succession]], [[Créatures]], [[Catalogue matériaux — Paramétriques]]
- **Voir aussi** : [[Habitat des PNJ]], [[Population et exploitation]], [[Noms culturels]], [[Équipement — 14 slots]], [[Wu Xing — cycles et vecteurs]], [[Sauvegarde]], [[Localisation]]
