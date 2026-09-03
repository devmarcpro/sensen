---
aliases: ["Décision — Vocabulaire d'attaque des créatures", "Ouvert — Vocabulaire d'attaque des créatures", "Attaques des créatures", "creature_actions"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable au playtest comme toute décision.

**La décision : les créatures parlent le même vocabulaire que les modules.**

**Schéma `data/creature_actions/*.json`** — une action de créature utilise exactement les six axes de [[Vocabulaire des modules — six axes]] : `forme`, `portee [min,max]`, `cible`, `couts` (ticks/endurance), `conditions`, `effets` (+ `elements` pour le vecteur Wu Xing). Aucun système nouveau : le résolveur de combat les exécute comme des capacités.

**Règles :**
- Chaque créature ([[Schéma créature]]) référence `actions: [ids]` — **2 à 4 actions par créature**, partagées par famille (toutes les meutes de loups utilisent `morsure`, `harcelement_meute`...).
- **Télégraphe** : toute action de coût **> 10 ticks** affiche son icône d'intention ET sa zone d'effet sur la grille dès que le compteur de la créature l'engage — cohérent avec [[Attaque lourde et télégraphe]] (*le télégraphe est une information d'interface*). Les actions ≤ 10 ticks s'exécutent sans préavis (le tempo rapide est leur identité).
- L'IA ([[IA des créatures]]) choisit parmi `actions` via ses considérations utility — l'action est une donnée, le choix est le profil.

**Le catalogue** ([[Créatures]] : 19 races animales) : produit dans [[Actions des créatures]] — **24 actions** les couvrent toutes par partage familial. Les **humains** n'ont pas d'actions dédiées : ils utilisent le système standard du joueur ([[Profils de PNJ]]).

> [!success] Codé — trace ajoutée le 2026-09-04
> `data/creature_actions/` (une action = dés, portée, ticks, `cout_vigueur`, effets : soin, invocation, statut…) et `combat_rules.actions` ; les créatures listent leurs actions, l'IA choisit par considérations. Sept fiches et six actions ajoutées le 2026-08-30 pour les types d'ennemis.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Schéma créature]], [[IA des créatures]], [[Trous connus du combat]]
- **Alimente** : [[Actions des créatures]], [[Combat tactique sur grille]], [[Attaque lourde et télégraphe]]
- **Voir aussi** : [[Créatures]], [[Data-driven design]]
