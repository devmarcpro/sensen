---
aliases: ["E.31", "Annexe E.31", "Génération de noms", "Algorithme de nommage"]
tags: [êtres, technique, décidé]
domaine: êtres
statut: décidé
etape: 9
---

L'algorithme de nommage, identique pour prénom, nom de famille et ville — et la fonction d'affichage unique réutilisée partout.

```
ALGORITHME (identique pour prénom/nom de famille/ville) :
  nom = pick_random(culture.X_a) + pick_random(culture.X_b)
  (concaténation directe ; pas de règle de jonction — les pools sont
  écrits pour s'enchaîner proprement à l'écriture des données)

PRÉNOM (instanciation d'un PNJ humanoïde civil/unique, B.5) :
  culture = royaume_local.culture (B.9) — ou culture par défaut de la
    race si le PNJ n'est pas rattaché à un royaume (ex. ermite)
  prenom = pick(culture.prenom_a) + pick(culture.prenom_b)

NOM DE FAMILLE (hérité, cohérent avec la démographie 12.2) :
  Si le PNJ a un parent (family.child_of) → hérite du nom de famille
    du parent (celui à l'index 0 si parents multiples/lignée
    paternelle/maternelle non distinguée — simplification assumée).
  Sinon (PNJ fondateur, généré directement par E.25/immigration) :
    nom_famille = pick(culture.famille_a) + pick(culture.famille_b)

TITRE (uniquement si `leadership_role` non nul, à l'obtention du
  rôle — génération initiale OU succession, E.25) :
    Monarchie/théocratie/dictature/ploutocratie/république → titre =
      culture.titres[government_type_du_royaume][genre_du_pnj]
    Maître de guilde (indépendant du royaume, 7.3) → titre =
      culture.titres["guilde_maitre"][genre_du_pnj]
  Affichage : `"{titre} {prenom} {nom_famille}"` (ou `"{titre}
  {nom_famille} {prenom}"` si `name_order: "nom_prenom"`) — résolu
  en une fonction d'affichage unique réutilisée partout (fiches PNJ,
  dialogue E.23, journal de raid E.6, quêtes B.7).

VILLE (à la génération d'un royaume, E.27, pour la capitale et
  chaque village/ville placé) :
    nom_ville = pick(royaume.culture.ville_a)
              + pick(royaume.culture.ville_b)
  Toutes les localités d'un même royaume tirent dans la même culture
  → cohérence sonore à l'échelle du royaume (E.27 s'y raccorde
  directement, aucune étape supplémentaire).

COÛT — génération one-shot à l'instanciation (PNJ) ou à la création
  du royaume (villes), jamais recalculée ; stockée comme toute donnée
  d'instance (E.10). Zéro coût récurrent.
UNICITÉ — non garantie (deux "Li Wei" peuvent exister dans des
  royaumes différents, comme dans la réalité) ; au sein d'un même
  royaume, un nouveau tirage identique à un PNJ vivant est re-tiré
  une fois (évite les doublons directs sans complexifier l'algorithme).
```

## Liens
- **Dépend de** : [[Noms culturels]], [[Culture de nommage — schéma]], [[Schéma créature]]
- **Alimente** : [[Génération des royaumes PNJ]], [[Familles et succession]], [[Dialogue PNJ]]
- **Voir aussi** : [[Âge des PNJ]], [[Schéma royaume]], [[Sauvegarde]], [[Localisation]], [[Cultures de nommage]]
