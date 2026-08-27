---
aliases: ["Structure des compétences", "Slots", "Compétences et modules", "Structure compétences/modules/slots"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

L'emboîtement arme → compétences → modules, façon Noita + Elin, et la croissance des slots avec le niveau d'arme.

**Structure des compétences (façon Noita + Elin) :**
- Chaque **type d'arme** possède un nombre de **slots de compétences**.
- Chaque **compétence** possède un nombre de **slots de modules**.
- Les **modules** s'assemblent façon Noita (modificateurs de sort/attaque) et sont **communs à toutes les armes** : n'importe quel module peut s'équiper dans n'importe quel type d'arme (pas de restriction par arme).
- Chaque module a un **coût en mana** : plus un module/sort est complexe, plus il coûte de mana à utiliser.
- Le **mana se régénère façon Elin** : récupération passive dans le temps (chance de récupération par tour, influencée par une compétence dédiée), accélérée par le repos. Voir [[Mana]].

**Décision — Slots : croissants avec le niveau d'arme :**
- slots de compétences par arme = `2 + floor(N_arme/20)` (**max 6**) ;
- slots de modules par compétence = `2 + floor(N_arme/25)` (**max 5**).

La progression d'arme débloque de la **complexité de build**, pas seulement des chiffres.

**Coût en mana d'une compétence assemblée ([[Mana]]) :**
```
cout_total = somme des couts des modules équipés dans la compétence
cout_module_effectif = cout_base_module / skill_factor(N_module)
```
Monter un module en niveau le rend plus puissant ET moins coûteux (puissance : `effet_base * skill_factor(N_module)`).

**Les capacités hors slots ([[Talents de classe]]) :** un **talent de classe** est un module qui **n'occupe aucun emplacement** et n'a pas besoin d'être trouvé. Il monte par l'usage comme les autres. C'est la seule chose qui échappe au compte de slots — et c'est volontaire : *le talent est un plancher, pas une cage*, les slots restent entièrement libres pour ce qu'on ramasse.

**Les jauges de classe ([[Talents de classe]]) :** certains talents portent une barre propre à la classe (la jauge de sang de L'Écarlate), calquée sur la [[Jauge de chaîne Wu Xing]] — **même objet de code, autres conditions de remplissage**. Aucun système parallèle.

**Règles d'assemblage détaillées :** voir [[Six types de modules et assemblage]].

**Écran dédié ([[Écrans d'interface]]) :** *Assemblage de compétences (slots armes/modules, coûts mana)*.

> [!success] Décidé le 2026-08-27 — le niveau d'un module réduit aussi ses ticks
> Tranché par le designer : « plus une attaque est complexe, plus elle coûte de ressources et de ticks ; moins si les modules employés sont haut niveau ». En plus de `cout_module_effectif = cout_base / skill_factor(N_module)` (ressource, sans plancher), chaque module de la séquence contribue `ticks_effectifs = max(ticks_base × 0,5, ticks_base / skill_factor(N_module))` — **plancher à 50 %** : la complexité coûte toujours du temps, un module de niveau 100 ne devient jamais gratuit. Les surcoûts en ticks des formes, modificateurs, conditions, déclencheurs et liaisons suivent la même règle, chacun avec son propre niveau.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Progression par l'usage]]
- **Alimente** : [[Six types de modules et assemblage]], [[Mana]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Grimoires et manuels]], [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Écrans d'interface]], [[Tooltips contextuels]]
