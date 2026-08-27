---
aliases: ["Armes fantomatiques", "Arme fantomatique", "Pureté élémentaire"]
tags: [combat, wuxing, objets, décidé]
domaine: combat
statut: décidé
etape: 0
---

La seule source fiable de pureté élémentaire — et l'accès au cycle des invocateurs.

**Les ARMES FANTOMATIQUES sont pures par nature** : invoquées, sans composants, donc toujours `{élément: 1.0}` — multiplicateurs pleins, segment net. En contrepartie :
- dégâts moindres (**~×0.7**) ;
- **entretien en mana** ;
- **ni sertissables ni enchantables** ;
- progression sur le **niveau d'élément et la Volonté** au lieu des matériaux.

C'est la **seule source fiable de pureté**, et l'accès au cycle des invocateurs ([[Cinq accès au cycle]]).

**Bloc canonique ([[Domination et multiplicateurs]]) :**
```
  ARMES FANTOMATIQUES : invoquées, sans composants → {élément: 1.0}
  toujours. Dégâts ~x0.7, entretien en mana, ni sertissables ni
  enchantables, progression sur le niveau d'élément et la Volonté.
  Seule source fiable de pureté.
```

**Alternative matérielle :** une arme **mono-élément** se fabrique en engageant tous ses composants dans la même famille — le coût est matériel et réel (un manche métallique est dense et conducteur, une tête en bois est faible). Voir [[Craft compositionnel]] et [[Stats et qualité de l'assemblage]].

**Raccord avec les invocations ([[Familles de capacités de la grille]]) :** *une créature invoquée occupe une tuile — elle est donc un mur, un bloqueur de vue et une menace de flanc autant qu'un allié. Raccord direct avec les compagnons ([[Compagnons]]) et les armes fantomatiques.*

> [!success] Codé le 2026-08-28
> Clic droit sur sa tuile → *Invoquer une lame de Feu / Eau / Bois / Métal / Terre* (`combat_rules.armes_fantomes` : 10 de mana, 4 ticks). L'arme est un objet transitoire (`fantome: true`, `fini: true`, jamais dans `objets` — non sauvegardée, non échangeable), une **épée** (`functionality: epee`) d'élément pur `{élément: 1.0}` qui prend la main principale (l'arme portée retourne au sac ; une lame précédente se dissipe). **Dégâts × 0,7** dans `_frapper_arme`. **Entretien** : 1 de mana toutes les 10 ticks, prélevé au pas de l'horloge de l'être ; à mana 0, ou si la lame quitte la main (râtelier, sac), elle **se dissipe**. **Progression** : `durete_base = durete_reference × (1 + Volonté / 50 + niveau de Magie / 100)` — décision : le « niveau d'élément » de la note est porté par la compétence Magie (une compétence par domaine n'est pas encore modélisée par élément). **Ni sertissable ni enchantable** : `fini`. Les invocateurs ont leur accès au cycle sans râtelier.

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Domination et multiplicateurs]], [[Mana]]
- **Alimente** : [[Cinq accès au cycle]], [[Jauge de chaîne Wu Xing]]
- **Voir aussi** : [[Craft compositionnel]], [[Familles de capacités de la grille]], [[Loot — affixes, gemmes et rareté]], [[Stats de personnage]], [[Ouvert — Compensation de l'arme mixte]]
