---
aliases: ["A.10", "Annexe A.10", "Mort", "Mort et pénalité", "Respawn"]
tags: [progression, formule, décidé]
domaine: progression
statut: décidé
etape: 4
---

Pas de permadeath : on pénalise l'économie, jamais la progression.

```
À la mort : respawn au dernier lit/claim activé.
Pénalité : -10 % de l'or transporté, chaque objet de l'inventaire a 10 % de
chance de tomber au sol sur le lieu de mort (récupérable pendant 1 jour in-game).
Équipement porté : conservé. XP de compétences : aucune perte (la progression
usage-based rend la perte d'XP très punitive, on pénalise l'économie à la place).
```

*(Alternative plus dure à tester en playtest : perte de 5 % de l'XP du niveau en cours sur les 3 compétences les plus hautes.)*

**Puits d'or ([[Économie — sources et puits]]) :** les −10 % d'or transporté sont **détruits** — un puits ponctuel déjà en place.

**Cadre ([[Progression par l'usage]]) :** pas de permadeath — mort avec pénalité, puis respawn.

**Mort d'un compagnon :** règles distinctes, voir [[Compagnons]] (mort réelle, mais résurrection payante).

**Mort d'un PNJ unique :** définitive pour l'individu, voir [[Familles et succession]].

> [!success] Codé le 2026-08-27
> Le joueur mort attend une touche : intention `respawn` → relevé au **point d'entrée** (arène ou étage — pas encore de lit ni de claim), PV et endurance pleins, statuts effacés, sorti de l'horloge de combat ; **10 % de chance par objet du sac** de tomber en butin sur le lieu de mort (`combat_rules.mort`) ; équipement et XP conservés ; l'or n'existe pas encore (−10 % en données, en attente).

> [!success] Précisé le 2026-08-28
> Le respawn se fait désormais **au dernier lit où l'on a dormi** (le camp) : mourir en donjon termine l'expédition et ramène au camp, les pertes du sac tombant sur le lieu de mort. Sans lit activé, l'ancien comportement (point d'entrée) reste.

> [!success] Codé le 2026-08-31 — les −10 % d'or sont prélevés
> `combat_rules.mort.perte_or` existait mais n'était lu nulle part (« pas d'or encore » disait la note de règles — l'or existe depuis les boutiques). `_respawn` retire désormais `floor(or × perte_or)` et le journal le dit (`journal.mort_or`). Test dans `test_progression`.

## Liens
- **Dépend de** : [[Progression par l'usage]]
- **Alimente** : [[Économie — sources et puits]]
- **Voir aussi** : [[Compagnons]], [[Familles et succession]], [[Meubles]], [[Claims et persistance]]
