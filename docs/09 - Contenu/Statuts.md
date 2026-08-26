---
aliases: ["F.4", "Annexe F.4", "Statuts", "status_effects", "14 statuts"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

Les 17 statuts de départ, en données.

`data/status_effects/` (17) :

**Ajoutés le 2026-08-26** ([[Talents de classe]]) : **Dissimulé** (hors du cône de détection tant qu'on n'attaque pas ; rompu par l'attaque — [[IA des créatures]]) · **Saisi** (porté par un autre : ne peut agir, libère sa tuile, projetable — effet `saisie`) · **Retardé** (marqueur visible d'un compteur repoussé — effet `tempo` ; **compte dans le budget anti-stunlock**, [[Statuts de contrôle et anti-stunlock]]).

Brûlure (1d4 feu/tour, 3 tours, retiré par eau) · Ralentissement (−30 % vitesse/coûts ticks +30 %) · Gel (immobilisé, jet de Force/tour) · Poison (1d3/tour jusqu'à purge, cumule) · Saignement (1d4/tour, stoppé par soin ou bandage) · Étourdi (perd son prochain tour de décision) · Confusion (30 % d'agir au hasard) · Terreur (fuit la source) · Infection (Endurance −2/jour jusqu'à soin — maladie longue) · Affaibli (−20 % stats, post-résurrection [[Compagnons]]) · Régénération (+1d4 PV/tour) · Peau de pierre (+2d4 armure) · Hâte (coûts ticks −20 %) · Béni (+1 à tous les jets, sanctuaires) · **Dissimulé** · **Saisi** · **Retardé**

**Application ([[Pipeline de résolution du combat]]) :** appliqués par tags des modules, tickés en phase 2 de la [[Boucle de tick]].

**Résolution ([[Résolveur de modificateurs]]) :** les statuts sont l'une des sources du résolveur unique — comme les potions ([[Nourriture, potentiel et potions]]).

**Contrôles durs bornés ([[Statuts de contrôle et anti-stunlock]]) :** étourdissement et enracinement se mesurent en ticks ; aucun contrôle dur ne dépasse 20 ticks sur le joueur, et ne peut se réappliquer dans les 50 ticks suivant sa fin.

**Sources hors combat :** échec de lecture ([[Lecture des livres]] : Étourdi, Confusion) · viande crue et ration moisie ([[Nourriture]] : Infection, Poison) · moustiques et scorpions ([[Créatures]]) · lave et eau ([[Eau et liquides]] : l'eau éteint la Brûlure).

**Durée modulée par gemme ([[Loot — affixes, gemmes et rareté]]) :** l'Opale taillée donne durée des statuts ou Volonté/Charisme.

> [!success] Décidé le 2026-08-26 — les statuts en données (`data/status_effects/`, `tools/gen_status_effects.py`)
> Le « tour » de l'ancien texte vaut **une période de 10 ticks** (`periode_ticks`). Un statut est `{degats_des, element, periode_ticks, duree_ticks, controle, cumule, modifiers, tags}` ; les `modifiers` visent une cible générique — `cout_ticks` (×), `degats` (×), `armure` (+), `compteur` (+ à l'application), `deplacement` / `garde` (bloqué) — et les systèmes lisent ces cibles et les tags (`dot`, `controle`, `interrompt`), jamais l'id. **14 statuts écrits** : Brûlure (1d4 Feu / 10 t, 30 t), Poison (1d3 / 10 t, 50 t, **cumule**), Saignement (1d4 / 10 t, 40 t), Infection (marqueur), Ralentissement (coûts ×1.3), Hâte (×0.8), Hâte de meute (×0.9 — le Hurlement), Ralliement (dégâts ×1.15 — le Cri), Étourdi (contrôle : +10 au compteur, **interrompt**), Enracinement (contrôle : déplacement bloqué), Retardé (marqueur du tempo subi), Égide (+6 d'armure), Garde annulée (la Feinte), Terreur (contrôle). Un statut non cumulable se **rafraîchit** (la fin est repoussée, jamais additionnée). Les dégâts périodiques sont tiqués en fin de pas pour tous les êtres de l'horloge (phase 2 de [[Boucle de tick]]), et versent l'XP à leur source.

## Liens
- **Dépend de** : [[Data-driven design]], [[Pipeline de résolution du combat]], [[Statuts de contrôle et anti-stunlock]]
- **Alimente** : [[Modules]], [[Potions]], [[Nourriture, potentiel et potions]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Compagnons]], [[Lecture des livres]], [[Eau et liquides]], [[Nourriture]], [[Créatures]], [[Loot — affixes, gemmes et rareté]]
