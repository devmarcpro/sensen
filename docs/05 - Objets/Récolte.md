---
aliases: ["A.2", "Annexe A.2", "Récolte", "4.2 récolte", "Filons de surface"]
tags: [objets, matériaux, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

Chercher des ressources, c'est explorer, pas creuser : des filons de surface, un outil adapté, et une règle d'irrécoltabilité qui sert de verrou de progression.

**Récolte des ressources (façon Elin, pas de minage exploratoire)** : les minerais, pierres et argiles apparaissent en **filons de surface** — des nœuds visibles sur la grille, récoltables à l'outil approprié, qui se régénèrent avec les cases sauvages ([[Claims et persistance]]). Le bois s'abat, les plantes se cueillent, les créatures se dépècent. Chercher des ressources, c'est **explorer**, pas creuser.

**Trois facteurs :**
- Chaque catégorie de matériau est associée à un outil dédié (hache → bois, pioche → minerai/roche, etc. — [[Catégories de matériaux]]).
- La **vitesse** et la **quantité** récoltées dépendent de trois facteurs combinés :
  1. Le niveau du joueur dans la compétence de récolte associée au matériau visé (ex : Minage pour minerai/roche).
  2. La dureté du matériau récolté.
  3. La dureté des matériaux composant l'outil utilisé.
- **Important :** les matériaux bruts n'ont pas de "qualité" — seulement leurs stats fixes. La récolte n'améliore jamais la qualité d'un matériau, seulement la vitesse/quantité obtenue.

**Formules (A.2) :**

```
temps_recolte (secondes) =
  durete_materiau / (durete_outil * qualite_outil * skill_factor(N_recolte))

quantite_recoltee = 1 + floor(N_recolte / 10)    (chance de +1 par palier de 10 niveaux)
XP gagnée par bloc récolté = durete_materiau
```

- Un matériau est **irrécoltable** si `durete_outil * qualite_outil < durete_materiau * 0.5` (outil trop faible : aucun progrès, feedback visuel "l'outil rebondit").
- Récolte à mains nues : dureté d'outil implicite = 1, qualité = 1.

**Verrou de progression ([[Stratification verticale]]) :** combinée à la stratification par dureté, la règle d'irrécoltabilité fait que creuser profond exige de meilleurs outils, de meilleurs matériaux (trouvés en profondeur) ou des PNJ mineurs de haut niveau.

**Rôle de case dédié ([[Rôles de cases]]) :** « Ressources naturelles » — la case garde la régénération hebdomadaire malgré le claim, réserve d'exploitation renouvelable.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]], [[Progression par l'usage]], [[Qualité d'artisanat]]
- **Alimente** : [[Stratification verticale]], [[Rôles de cases]], [[Population et exploitation]]
- **Voir aussi** : [[Claims et persistance]], [[Minerais par profondeur]], [[Fabrication d'outils]], [[Compétences — liste]], [[Décisions fondatrices]]
