---
aliases: ["B.7", "Annexe B.7", "Gabarit de quête", "quest_templates"]
tags: [société, données, schéma, décidé]
domaine: société
statut: décidé
etape: 9
---

Le format d'un gabarit de quête procédurale, avec son sélecteur de cible et son texte localisé à placeholders.

`data/quest_templates/*.json` :

```json
{
  "id": "chasse_prime",
  "guild": "guerriers",
  "rank_min": 1,
  "pattern": "tuer",
  "target_selector": { "tags_any": ["hostile"], "combat_level_range_around_player": [0.8, 1.2] },
  "count_range": [3, 8],
  "reward": { "gold_per_target_level": 15, "guild_xp": 10 },
  "text_key": "quest.chasse_prime.text"
}
```

- `text_key` pointe vers un gabarit localisé avec placeholders (ex : fr = "Éliminez {count} {target} près de {location}.") — une version par langue dans `locale/` (voir [[Localisation]]). Les valeurs `{target}`/`{location}` sont elles-mêmes résolues via les `name_key` des entités concernées.
- **Pattern `"donjon"`** ([[Quêtes et guildes]]/[[Donjons — structure et intégration]]) : `target_selector` référence un donjon POI généré à proximité plutôt qu'un type de créature — objectif "atteindre l'étage le plus profond" ou "vaincre le boss" (`dungeon_cleared` sur l'EventBus valide la quête automatiquement).

**Sélection de cible par niveau de combat ([[Double niveau combat et général]]) :** `combat_level_range_around_player` — le niveau de combat sert au scaling des menaces de quête.

**Écoute d'événements ([[EventBus]]) :** le système de quêtes écoute `creature_killed`, `item_crafted`, `block_placed/destroyed`, `dungeon_cleared` sans que ces systèmes connaissent les quêtes.

> [!success] Codé le 2026-08-28 — sept patterns, douze guildes servies
> `tuer` et `donjon` (existants) + **`livrer`** (transporteurs : un objet tiré de `target_selector.items_any`, à remettre en parlant à un PNJ d'un **autre village connu** — `{objet}`, `{destination}` dans le texte), **`construire`** (bâtisseurs : poser N meubles, stations ou murs sur son territoire), **`fabriquer`** (artisans : composants et objets ; enchanteurs : composants ; alchimistes : potions ; cuisiniers : plats — `target_selector.kinds_any`), **`vendre`** (marchands : N objets vendus à des PNJ), **`explorer`** (éclaireurs : N chunks découverts). Les mages chassent des hostiles à prime relevée. Un seul progresseur générique (`_progresser_quetes(pattern, tags)`) branché sur pose, fabrication, vente, récolte, exploration et dialogue — les systèmes ne connaissent pas les quêtes.

> [!success] Corrigé le 2026-08-29 — `rank_min` n'était lu par personne
> Le champ figure dans le gabarit depuis l'étape 9, mais **aucune ligne de code ne le lisait** : un novice tout juste inscrit se voyait offrir n'importe quelle quête de sa guilde, y compris les deux « vider un donjon » à 60 or par niveau. `quetes_offertes` filtre désormais les gabarits sur le **rang du joueur dans la guilde du gabarit**. Décisions : `rank_min` se lit en **rangs affichés** (1 = Novice … 5 = Maître), les rangs internes étant indexés à 0 — c'est ce que dit l'exemple de la note (`rank_min: 1` = ouvert à tous, ce qu'étaient déjà toutes les fiches) ; **`donjon` et `purge` passent à 2** (Compagnon), les seules quêtes qui envoient seul au fond d'un donjon et les mieux payées. Le tirage de la semaine reste **mis en cache par donneur** : un rang gagné en milieu de semaine n'ouvre les nouvelles quêtes qu'à la semaine suivante.

> [!success] Corrigé le 2026-08-29 — la livraison tirait dans cinq ids
> Dernière liste d'ids du chantier « des catégories, pas des choses » : `livraison.target_selector.items_any` nommait cinq denrées. Devenu `target_selector.filtre` (les consommables empilables, ni partie, ni âme, ni potion, ni bombe) résolu par `GameData.tirer` — tout aliment ajouté au jeu peut être demandé en livraison. L'audit refuse désormais `items_any`. **Ce qui reste volontairement des listes** : le coffre de départ (`camp.json`, un kit choisi — c'est une décision de design, et ses trois champs morts `arbres/rochers/filons` sont retirés), les plans de bâtiments (`village_buildings.*.meubles`, un plan est une chose), les faunes de biome (des espèces choisies par biome, comme la note *Biomes* le prescrit).

> [!success] Constaté le 2026-09-03 — `item_crafted` n'est pas un signal, et le sélecteur s'appelle `kinds_any`
> Une quête de fabrication avance par un appel direct, `_progresser_quetes(e, "fabriquer", tags)`, au moment où l'objet sort de l'atelier ; il n'y a pas de signal `item_crafted`. Le sélecteur d'objets d'un gabarit est codé sous `kinds_any` (une liste de sortes : plat, potion, objet…), pas `items_any`.

## Liens
- **Dépend de** : [[Quêtes et guildes]], [[Data-driven design]], [[Double niveau combat et général]]
- **Alimente** : [[Donjons — structure et intégration]], [[Économie — sources et puits]]
- **Voir aussi** : [[Localisation]], [[EventBus]], [[Créatures]], [[Génération de donjon]], [[Génération de noms]]
