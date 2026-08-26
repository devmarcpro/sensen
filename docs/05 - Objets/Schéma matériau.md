---
aliases: ["B.1", "Annexe B.1", "Schéma matériau", "data/materials", "B.12"]
tags: [objets, matériaux, données, schéma, décidé]
domaine: objets
statut: décidé
etape: 6
---

Le format de données d'un matériau, avec ses stats, son bruit, sa récolte et sa génération — plus les règles de couleur unique et de tags dérivés.

`data/materials/*.json` :

```json
{
  "id": "chene",
  "name_key": "material.chene.name",
  "category": "bois",
  "stats": {
    "durete": 12, "densite": 6, "valeur_base": 4,
    "conductivite_mana": 10, "flammabilite": 60, "isolation": 35,
    "conductivite_electrique": 5, "flottabilite": 80, "luminosite": 0,
    "fertilite": 0, "transparence": 0, "elasticite": 25, "friction": 45
  },
  "tags": ["organique"],
  "color": "#8B5A2B",
  "noise": {
    "type": "procedural",
    "seed_offset": 101,
    "amplitude": 0.08,
    "scale": 4
  },
  "harvest": {
    "tool_category": "hache",
    "skill": "bucheronnage"
  },
  "world_gen": {
    "mode": "biome",
    "biome_tags": ["foret", "tempere"]
  }
}
```

- `world_gen.mode` : `"biome"` (découle du biome) ou `"noise_layer"` (couche de bruit dédiée, avec `noise_layer_id` et seuils).
- `noise.type` : `"procedural"` ou `"texture"` (matériaux spéciaux, avec `texture_path`).
- **`composition`** (4.3/A.12) : proportions élémentaires du matériau, ex. `{"Cu": 0.88, "Sn": 0.12}` pour le bronze, `{"Fe": 1.0}` pour le fer. Obligatoire pour tous les matériaux inorganiques (métaux, roches, minéraux, gemmes, terres) ; les matériaux organiques (bois, fibres, viandes) déclarent une composition simplifiée (`{"C": 0.5, "H": 0.06, "O": 0.44}` type biomasse) — extractibles mais peu rentables, ce qui est réaliste et évite l'exploit du bois infini.
- **Matériaux paramétriques** : certains matériaux sont des **gabarits instanciés depuis une source** plutôt que des entrées fixes — `"parametric": {"source": "creature"|"tree"}`. Ex. : *Viande de X*, *Peau de X*, *Os de X* (stats/bonus dérivés de la créature source, [[Schéma créature]]), *Feuilles de X*, *Pousse de X* (couleur/stats dérivées de l'essence, [[Catalogue matériaux — Paramétriques]]). Une seule définition couvre toutes les variantes — les 40 essences ont leurs feuilles sans 40 entrées ; la couleur d'une variante = couleur de la source décalée déterministiquement (pas de collision avec la palette [[Palette de couleurs des matériaux]], vérifiée au boot).
- **`color` : couleur UNIQUE par matériau** (obligatoire). GameData valide au boot qu'aucune couleur n'est dupliquée dans tout le catalogue ET qu'aucune n'entre en collision avec les couleurs réservées (stand-in matériaux + marqueurs d'attache, `data/reserved_colors.json`, [[Squelette modulaire et points d'attache]]) — un doublon = erreur bloquante de données. Deux matériaux visuellement proches (ex : pin/sapin) se distinguent par un écart minimal de teinte/valeur + leurs paramètres de bruit (`noise`) : la texture différencie ce que la couleur seule ne suffit pas à séparer. La palette complète de départ est en [[Palette de couleurs des matériaux]].
- **Tags dérivés automatiquement** des stats par seuils (>= 50) : `flammabilite` → `inflammable`, `conductivite_mana` → `conducteur_mana`, `flottabilite` → `flottant`, `isolation` → `isolant`, `luminosite` → `luminescent`, `transparence` → `transparent`, `conductivite_electrique` → `conducteur`. Les systèmes à tags ([[Data-driven design]]) réagissent aux tags ; les formules fines utilisent la valeur graduée. Seuls les tags non dérivables (ex : `organique`, `corrompu`) sont déclarés à la main.

> **Note (B.12) :** la référence « chaque élément porte les 13 stats standard (B.12) » de [[Composants]] renvoie au même jeu de 13 stats défini ici et en [[Matériaux — 13 stats]] ; l'annexe B ne porte pas de section B.12 distincte (héritage de la chimie élémentaire supprimée — voir [[Craft compositionnel]]).

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Data-driven design]]
- **Alimente** : [[Catégories de matériaux]], [[Palette de couleurs des matériaux]], [[Récolte]], [[Catalogue matériaux — Paramétriques]]
- **Voir aussi** : [[Application des stats de matériau]], [[Squelette modulaire et points d'attache]], [[Localisation]], [[Biomes — schéma]], [[Décisions d'architecture]]
