---
aliases: ["Recettes de composants", "Matrice composants × familles", "F.13"]
tags: [contenu, craft, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

> [!success] Rédigé le 2026-08-26
> La matrice complète composant × famille de matériaux, produite sur délégation — transcription directe en `data/component_recipes/` ([[Composant et recette d'obtention]]).

Quelles familles de matériaux fabriquent quel composant, où, et comment on apprend les recettes exotiques.

## Principes

- **Base = connue d'office** ; **exotique = à apprendre** (`unlock_sources`). Sources standard : `loot_donjon` (parchemin), `marchand_specialise`, `guilde_forgerons_rang_3` / `guilde_artisans_rang_3`, `enseignement_pnj` (relation ≥ 75, [[L'information comme récompense]]).
- **Le jeu démarre sans forge** : chaque outil de base a une voie **pierre/os** connue d'office à l'Établi ou au Tailleur de pierre — la boucle primitive (silex → pioche de pierre → minerai) fonctionne dès la première heure.
- Les stats suivent toujours les matériaux ([[Stats et qualité de l'assemblage]]) — *l'exotisme est dans l'accès, jamais dans un bonus caché*.

## La matrice ([[Composants]] × familles)

| Composant | Bases (station) | Exotiques (station · source) |
|---|---|---|
| **Manche court / long / Poignée** | bois (Scierie) | os (Établi · loot_donjon) · lingot_metal (Enclume · guilde_forgerons_r3) · ivoire/défense (Établi · marchand) |
| **Tête d'outil** | roche taillée (Tailleur de pierre) · lingot_metal (Enclume) | obsidienne (Tailleur · loot_donjon ou guilde_forgerons_r3) · os massif (Établi · loot_donjon) |
| **Lame courte / Lame longue** | lingot_metal (Enclume) | obsidienne (Tailleur · loot_donjon) · verre (Forge+Enclume · guilde_forgerons_r4) · os (Établi · loot_donjon) · or/argent (Enclume · marchand_specialise) |
| **Tête d'arme lourde** | lingot_metal (Enclume) · roche taillée (Tailleur) | granit noir (Tailleur · guilde_forgerons_r3) · météorite ferreuse (Enclume · loot_donjon, rare) |
| **Pointe** | lingot_metal (Enclume) · silex/roche (Tailleur) · os (Établi) | dent/croc (Établi · enseignement_pnj chasseur) · obsidienne (Tailleur · loot_donjon) |
| **Plaque** | lingot_metal (Enclume) | os massif (Établi · loot_donjon) · écaille de créature (Établi · enseignement_pnj) |
| **Sangles** | cuir (Atelier de tissage) · fibre — chanvre/lin (Tissage) | soie (Tissage · marchand_specialise) |
| **Rembourrage** | tissu (Tissage) · laine (Tissage) · fourrure (Tissage) | soie (Tissage · marchand_specialise) |
| **Fixations standard** | rivets — lingot_metal (Enclume) · ligatures — fibre (Tissage) · colle — sève (Alambic) | *(aucune — le slot générique doit rester trivial)* |
| **Garde** | lingot_metal (Enclume) | or/argent (Enclume · marchand_specialise) · os (Établi · loot_donjon) |
| **Contrepoids** | lingot_metal (Enclume) · roche (Tailleur) · plomb (Enclume) | or (Enclume · marchand_specialise) · tungstène (Laminoir · guilde_forgerons_r4) |

**Familles (`material_family`) référencées :** `bois` (toute essence), `lingot_metal` (tout métal fondu), `roche_taillee`, `silex`, `os`, `os_massif`, `dent_croc`, `ecaille`, `ivoire`, `obsidienne`, `verre`, `granit_noir`, `meteorite`, `or_argent`, `plomb`, `tungstene`, `cuir`, `fibre`, `tissu`, `laine`, `fourrure`, `soie`, `seve` — le joueur choisit librement le matériau *dans* la famille ([[Composant et recette d'obtention]]).

**Rappel niveaux de recette ([[Craft compositionnel]]) :** chaque recette a 5 niveaux par doublons ; l'axe du bonus est en [[Ouvert — Axe des niveaux de recette]] (défaut au balayage final).

> [!success] Transcrit le 2026-08-28 — `data/component_recipes/` (56 recettes)
> La matrice ligne par ligne ; bases connues d'office, exotiques avec leurs `unlock_sources`. « Or » seul (contrepoids) est la famille `or` ; « rivets/ligatures/colle » sont trois recettes de `fixations_std`.

> [!success] Codé (vérifié le 2026-08-28)
> La matrice est transcrite : 56 recettes d'obtention dans `data/component_recipes/`.

> [!success] Constaté le 2026-09-03 — pas de tête de pioche par matière : `tete_pioche_obsidienne` et `tete_pioche_metal` sont codés sous **`tete_outil`**
> Un composant est **à matériau libre** (Craft compositionnel) : la tête d'un outil est `tete_outil`, la matière vient de la recette de composant (`component_recipes/`), pas du nom. `guilde_artisans_rang_3` n'existe pas non plus : les débloquages se déclarent dans `unlock_sources` d'une recette.

## Liens
- **Dépend de** : [[Composants]], [[Composant et recette d'obtention]], [[Stations de transformation]]
- **Alimente** : [[Craft compositionnel]], [[Armure par zone et constructions]], [[Stats et qualité de l'assemblage]]
- **Voir aussi** : [[Catégories de matériaux]], [[L'information comme récompense]], [[Palier industriel]], [[Récolte]]
