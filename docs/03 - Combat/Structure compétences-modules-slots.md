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

**Règles d'assemblage détaillées :** voir [[Six types de modules et assemblage]].

**Écran dédié ([[Écrans d'interface]]) :** *Assemblage de compétences (slots armes/modules, coûts mana)*.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Progression par l'usage]]
- **Alimente** : [[Six types de modules et assemblage]], [[Mana]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Grimoires et manuels]], [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Écrans d'interface]], [[Tooltips contextuels]]
