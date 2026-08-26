---
aliases: ["Apprivoisement", "Recrutement", "Conditions de recrutement", "Dressage"]
tags: [êtres, société, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Comment on transforme n'importe quelle créature en compagnon : une action dédiée d'abord, une relation qui évolue ensuite.

**Conditions de recrutement :** variables selon le type de créature — un **mélange** de seuil de réputation/relation, d'action spécifique (objet, compétence de dressage), et/ou de quête dédiée selon les cas.

**Mécanique d'apprivoisement :** en deux temps — une **action dédiée** est nécessaire pour la première rencontre/le premier apprivoisement ([[Jet de compétence universel]] : `1d20 + Dressage/2 + Charisme/4 vs DD = 10 + niveau_combat_cible/2`, **cible affaiblie = bonus**), puis la **relation évolue ensuite** dans le temps comme pour tout autre PNJ (via le système de réputation/relations, [[Réputation et relations]]).

**Règle de recrutement par type ([[Squelette modulaire et points d'attache]], défauts surchargés par créature en [[Schéma créature]]) :**
- humanoïdes intelligents → `relation`
- bêtes/animaux → `dressage`
- PNJ uniques (rois, maîtres) → `dressage` à DD très élevé ou `quete`
- certains → `jamais`

**La relation individuelle est le critère ([[Réputation et relations]]) ;** les réputations race/royaume agissent en **modificateur de vitesse** du gain de relation (×0.5 à ×1.5 selon le palier), jamais en seuil direct. Les **compatibilités astrologiques** ([[Astrologie — cycle sexagésimal]]) s'y ajoutent comme second modificateur de vitesse.

**Faveur personnelle à relation 90-100 ([[L'information comme récompense]]) :** un PNJ *devient recrutable même si sa condition ne le prévoyait pas*.

**Capture ([[Population et exploitation]]) :** aucune créature n'est exclue des systèmes de capture/statut — **même les PNJ uniques ou importants (rois, chefs...) peuvent être capturés** et assignés en bétail, avec des conséquences de réputation proportionnelles.

**Signal :** `creature_recruited` sur l'EventBus, écouté par le royaume (population) et l'habitat ([[EventBus]]).

**Option de dialogue ([[Dialogue PNJ]]) :** « Recruter » s'affiche quand les conditions de `recruitable` sont approchées/remplies.

**Le cycle complet est spécifié — rien à développer de plus :**
1. **Approcher** — une créature `bete_sauvage` fuit si détectée ([[IA des créatures]]) ; la Discrétion ou l'appât (nourriture jetée au sol, [[Nourriture]]) permet d'arriver au contact.
2. **Tenter** — action dédiée au contact, jet universel ci-dessus. **Cible affaiblie = bonus : +5 au jet sous 50 % PV, +10 sous 25 %.** Échec → la créature devient hostile ou fuit (selon son profil) ; **une seule tentative par créature et par jour in-game**.
3. **Entretenir** — succès = la créature devient un compagnon à relation 0 ([[Compagnons]]) ; la relation évolue ensuite comme pour tout PNJ ([[Réputation et relations]]) : nourrir (+, plats cuisinés [[Cuisine et alchimie]]), combattre ensemble (+), la laisser mourir (−).

Aucune quête d'apprivoisement dédiée : `recruitable.method: "quete"` est réservé aux PNJ uniques ([[Schéma créature]]).

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Schéma créature]], [[Jet de compétence universel]], [[Réputation et relations]]
- **Alimente** : [[Compagnons]], [[Population et exploitation]], [[Habitat des PNJ]]
- **Voir aussi** : [[Astrologie — cycle sexagésimal]], [[L'information comme récompense]], [[Dialogue PNJ]], [[EventBus]], [[Tooltips contextuels]], [[Agriculture et élevage]]
