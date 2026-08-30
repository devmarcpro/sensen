---
aliases: ["A.4.6", "Annexe A.4.6", "Domination", "Multiplicateurs Wu Xing"]
tags: [combat, wuxing, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le bloc de formules canonique du Wu Xing : format de vecteur, domination offensive et défensive, dégâts par composantes et niveaux.

```
FORMAT UNIQUE — tout porte un VECTEUR : {metal: 0.75, bois: 0.25}
  armes, armures, créatures, modules, matériaux, lieux.
  Domaines : Feu {feu:1} · Eau/Glace {eau:1} · Terre {terre:1}
    · Métal {metal:1} · Foudre et Vie {bois:1} (attribution
    traditionnelle : le tonnerre du printemps, la croissance)
    · Arcane {0.2 partout} — quasi neutre PAR CONSTRUCTION, sans
      règle d'exception · Espace {eau:0.6, metal:0.4}
    · Corruption {terre:0.5, feu:0.5}   (défauts à équilibrer)

DOMINATION (Bois⊳Terre⊳Eau⊳Feu⊳Métal⊳Bois) :
  offensif : dominé x1.5 · dominant x0.65 · engendré x0.8 · sinon 1.0
  défensif : dominé x1.20 · dominant x0.85 · engendré x0.95
    (compression volontaire : un mauvais matchup défensif est un
     désagrément, jamais un mur — l'armure est permanente, 6.2)
  Vecteurs mixtes : mult = Σ (proportion_e × mult(e, cible)),
    double somme pondérée si la cible est elle-même mixte.

DÉGÂTS PAR COMPOSANTES ET NIVEAUX :
  degats = degats_base(matériaux, qualité, stats)
         × Σ_e [ proportion_e × (1 + niveau_élément_e / 100) ]
         × mult_domination
         × (1 + Σ bonus_transitions)   si coup final de chaîne
  → une arme MIXTE exige d'investir dans ses deux éléments pour
    égaler une PURE ; en échange son vecteur amortit les mauvais
    matchups. Spécialisation contre polyvalence, en chiffres.

ÉLÉMENT D'UNE ARME = CELUI DE SA TÊTE (les poids de slots A.4.7
  garantissent qu'elle domine). Mono-élément = tous les composants
  dans la même famille (coût matériel réel). Départage en cas
  d'égalité stricte : la tête, puis l'élément phare déclaré.
  ARMES FANTOMATIQUES : invoquées, sans composants → {élément: 1.0}
  toujours. Dégâts ~x0.7, entretien en mana, ni sertissables ni
  enchantables, progression sur le niveau d'élément et la Volonté.
  Seule source fiable de pureté.
```

*(Le bloc **JAUGE DE CHAÎNE** de A.4.6 vit dans [[Jauge de chaîne Wu Xing]] ; le bloc **MODIFICATEURS D'AFFINITÉ** dans [[Modificateurs d'affinité]] ; les blocs **COÛT DE MANA PAR LIEU** et **CUISINE** dans [[Wu Xing hors combat]]. Les quatre blocs forment ensemble l'annexe A.4.6 intégrale.)*

**Le mapping des domaines de magie vers le Wu Xing** est repris en [[Domaines de grimoires et manuels]].

**Niveaux d'élément :** ils progressent par l'usage via [[XP de combat]] (l'élément du coup est l'une des trois pistes) et sont régulés par le [[Potentiel]].

> [!success] Décidé le 2026-08-26 — ce que le code a fixé (`data/wuxing.json`, `systems/combat/wuxing.gd`)
> - **Quelle table s'applique** : un coup se résout contre le **vecteur de la pièce d'armure de la zone touchée** avec les multiplicateurs **défensifs compressés** (×1.20 / ×0.85 / ×0.95) ; si la zone est nue, contre l'**alignement propre de la créature** (`elements` de sa fiche) avec les multiplicateurs **offensifs** (×1.5 / ×0.65 / ×0.8) ; sans vecteur d'un côté ou de l'autre : ×1.0. Une attaque sans élément (bâton magique nu, bandit désarmé) n'est jamais modulée.
> - **Ordre des facteurs** : `bruts × Σ niveaux × domination × gain intermédiaire × (1 + Σ bonus) si résolveur`, puis zone de coup, garde, armure plate. Les **niveaux d'élément valent 0** dans le prototype (facteur 1) — ils arrivent avec la progression (étape 4).
> - **Alignements du bestiaire du prototype**, dérivés des éléments de leurs actions : Loup `{bois: 1}` · Sanglier `{terre: 0.6, metal: 0.4}` · Aigle `{metal: 0.5, bois: 0.5}` · Scorpion `{eau: 0.6, metal: 0.4}` ; les humains n'ont pas d'alignement propre, c'est leur armure qui répond (cuir = Bois, fer = Métal — [[Décision — Surcharges Wu Xing des matériaux]]).

> [!failure] Supprimé par le designer le 2026-08-31 — Arcane, Espace et Corruption ne sont plus des domaines
> Les vecteurs hors-cycle de l'annexe ci-dessus (« Arcane {0.2 partout} · Espace {eau 0.6, metal 0.4} · Corruption {terre 0.5, feu 0.5} ») sont retirés : un module sans élément ne pose pas de segment et ne subit aucune domination. Voir [[Ouvert — Répartitions Arcane Espace Corruption]].

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Progression par l'usage]]
- **Alimente** : [[Jauge de chaîne Wu Xing]], [[Pipeline de résolution du combat]], [[Armure par zone et constructions]], [[XP de combat]], [[Armes fantomatiques]]
- **Voir aussi** : [[Modificateurs d'affinité]], [[Wu Xing hors combat]], [[Stats et qualité de l'assemblage]], [[Domaines de grimoires et manuels]], [[Ouvert — Répartitions Arcane Espace Corruption]]
