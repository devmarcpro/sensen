---
aliases: ["E.23", "Annexe E.23", "Dialogue PNJ", "Dialogue", "Répliques d'ambiance", "Rumeurs"]
tags: [êtres, société, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Un menu contextuel façon Elona, pas un arbre : la profondeur vient des conditions, pas de la ramification.

```
STRUCTURE — interagir avec un PNJ ouvre un MENU CONTEXTUEL, pas un arbre :
  la réplique d'ambiance du PNJ s'affiche en haut, les options en dessous.
  Options AFFICHÉES SELON LE CONTEXTE (data-driven, conditions sur tags/
  état — section 10) :
    Parler        (toujours — retire une réplique d'ambiance, +micro-
                   relation 1x/jour/PNJ, jet de Charisme pour bonus)
    Commercer     (tag commerce_possible + PNJ marchand/étal)
    Quêtes        (PNJ donneur de quêtes / maître de guilde)
    Recruter      (conditions de recrutable B.5 approchées/remplies)
    Offrir un cadeau (objet de l'inventaire → relation selon valeur
                   et préférences du PNJ ; préférences par tags dans
                   la définition, ex. un érudit aime les livres)
    Donner un ordre (compagnons/suiveurs — E.17)
    Échanger équipement (compagnons)
    Assigner      (PNJ du territoire : job/logement/statut — 14.2, 7.5)
    Négocier      (contexte diplomatique 14.4 / marchandage de prix)
    Demander à suivre (suiveur territorial, E.17)
    Ressusciter un compagnon (prêtres uniquement, E.17)
    [Duel]        (autre joueur — PvP consenti, section 8)

RÉPLIQUES D'AMBIANCE — gabarits data-driven (data/dialogue/*.json) :
  { "id", "text_key", "conditions": {métier, humeur min/max, relation
    min/max, heure, biome/météo, événements récents (raid subi, roi
    capturé…), réputation du joueur (globale/royaume/race 7.2)} }
  Sélection : pool des gabarits dont les conditions matchent, tirage
  pondéré, anti-répétition (mémoire des N dernières répliques par PNJ).
  Exemples : un forgeron heureux le matin parle de sa forge ; un
  villageois d'un royaume dont vous avez capturé le roi vous insulte
  ou tremble (selon son courage) ; relation haute → confidences,
  rumeurs utiles (position de POI non découverts — récompense douce
  du social).
  LOCALISATION : chaque gabarit = une text_key par langue (10.1) ;
  les placeholders sont résolus via name_keys.
VOLUME DE DÉPART : ~15-20 gabarits génériques + 3-5 par métier ;
  le système est conçu pour en absorber des centaines sans code.
Pas d'arbres ramifiés ni de dialogue génératif : la profondeur vient
des conditions contextuelles, pas de la ramification — fidèle à Elona,
et un ordre de grandeur moins cher à produire et à localiser en 4
langues.
```

**Annonce météo ([[Météo]]) :** les extrêmes sont annoncés 1 jour in-game à l'avance — *les PNJ en parlent (gabarits météo, raccord existant)*.

**Filtrage par métier ([[L'information comme récompense]]) :** ce que le PNJ sait du monde est filtré par **métier** autant que par palier — sinon tous les PNJ deviennent le même distributeur.

**Écran dédié ([[Écrans d'interface]]) :** *Dialogue PNJ*.

## Liens
- **Dépend de** : [[Schéma créature]], [[Réputation et relations]], [[Data-driven design]]
- **Alimente** : [[L'information comme récompense]], [[Apprivoisement et recrutement]], [[Commerce et boutiques]], [[Compagnons]]
- **Voir aussi** : [[Génération de noms]], [[Localisation]], [[Météo]], [[Habitat des PNJ]], [[Population et exploitation]], [[Gouvernance, lois et diplomatie]], [[Multijoueur]], [[Écrans d'interface]]
