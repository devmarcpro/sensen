---
aliases: ["F.4", "Annexe F.4", "Statuts", "status_effects", "14 statuts"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

Les 14 statuts de départ, en données.

`data/status_effects/` (14) :

Brûlure (1d4 feu/tour, 3 tours, retiré par eau) · Ralentissement (−30 % vitesse/coûts ticks +30 %) · Gel (immobilisé, jet de Force/tour) · Poison (1d3/tour jusqu'à purge, cumule) · Saignement (1d4/tour, stoppé par soin ou bandage) · Étourdi (perd son prochain tour de décision) · Confusion (30 % d'agir au hasard) · Terreur (fuit la source) · Infection (Endurance −2/jour jusqu'à soin — maladie longue) · Affaibli (−20 % stats, post-résurrection [[Compagnons]]) · Régénération (+1d4 PV/tour) · Peau de pierre (+2d4 armure) · Hâte (coûts ticks −20 %) · Béni (+1 à tous les jets, sanctuaires)

**Application ([[Pipeline de résolution du combat]]) :** appliqués par tags des modules, tickés en phase 2 de la [[Boucle de tick]].

**Résolution ([[Résolveur de modificateurs]]) :** les statuts sont l'une des sources du résolveur unique — comme les potions ([[Nourriture, potentiel et potions]]).

**Contrôles durs bornés ([[Statuts de contrôle et anti-stunlock]]) :** étourdissement et enracinement se mesurent en ticks ; aucun contrôle dur ne dépasse 20 ticks sur le joueur, et ne peut se réappliquer dans les 50 ticks suivant sa fin.

**Sources hors combat :** échec de lecture ([[Lecture des livres]] : Étourdi, Confusion) · viande crue et ration moisie ([[Nourriture]] : Infection, Poison) · moustiques et scorpions ([[Créatures]]) · lave et eau ([[Eau et liquides]] : l'eau éteint la Brûlure).

**Durée modulée par gemme ([[Loot — affixes, gemmes et rareté]]) :** l'Opale taillée donne durée des statuts ou Volonté/Charisme.

## Liens
- **Dépend de** : [[Data-driven design]], [[Pipeline de résolution du combat]], [[Statuts de contrôle et anti-stunlock]]
- **Alimente** : [[Modules]], [[Potions]], [[Nourriture, potentiel et potions]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Compagnons]], [[Lecture des livres]], [[Eau et liquides]], [[Nourriture]], [[Créatures]], [[Loot — affixes, gemmes et rareté]]
