---
aliases: ["C.9", "Annexe C.9", "Cultures de nommage", "7 cultures", "10 cultures", "Cultures"]
tags: [contenu, société, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

Les 7 cultures de lancement — purement phonétiques et toponymiques, **toutes inspirées de peuples réels**.

> [!warning] Trois cultures retirées le 2026-08-26
> **Sylvestre**, **Ignée** et **Résonance** étaient dédiées aux races inventées (Sylvide, Cendreux, Échomorphe), désormais supprimées ([[Races]]). Il ne reste que des cultures inspirées du monde réel — le mécanisme (`race_affinity`, tirage par race dominante) est inchangé.

*Purement phonétique/toponymique — aucune donnée de gameplay différenciée par culture au-delà des pools de noms et titres ([[Culture de nommage — schéma]]). Affinité de race entre parenthèses.*

Latine/romane (Humain) · Nordique/germanique (Nain, Humain) · Sino (Humain) · Nipponne (Humain) · Slave (Humain) · Arabo-berbère (Humain) · Celte (Elfe, Humain).

**Décision ([[Noms culturels]]) :** *Cultures de lancement : 7 — assez pour une vraie variété sans exploser le volume de contenu à la main.*

**Culture ≠ race ([[Noms culturels]]) :** deux axes indépendants — un royaume humain peut tirer n'importe quelle culture, un royaume nain penche vers le nordique. Le champ `race_affinity` porte les poids de tirage ([[Culture de nommage — schéma]]).

**Exemple canonique :** `culture_sino` — voir [[Culture de nommage — schéma]] (avec ses titres par gouvernance et son `name_order: "nom_prenom"`).

**Tirage à la génération d'un royaume ([[Génération des royaumes PNJ]]) :** pondéré par `race_affinity` selon la race dominante.

**Les pools sont écrits :** [[Pools de noms des cultures]] (les 9 cultures restantes ; la Sino vit dans [[Culture de nommage — schéma]]).

> [!success] Constaté le 2026-09-03 — les identifiants des cultures et des pools ne portent pas le préfixe
> Une culture s'appelle `sino`, `celte`, `nordique`… (pas `culture_sino`), et ses pools sont séparés par genre : `prenom_a`, `prenom_b_m` / `prenom_b_f`, `famille_a`, `famille_b_m` / `famille_b_f`, `ville_a`, `ville_b`, `titres` — `famille_b` et `prenom_b` n'existent pas tels quels.

## Liens
- **Dépend de** : [[Noms culturels]], [[Culture de nommage — schéma]], [[Races]]
- **Alimente** : [[Génération de noms]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Localisation]], [[Ouvert — Pools de noms des cultures]]
