---
aliases: ["E.26", "Annexe E.26", "Lois et infractions", "Infractions", "Douanes", "Contrebande", "Discrétion"]
tags: [société, technique, décidé]
domaine: société
statut: décidé
etape: 10
---

Le pipeline d'infraction : une infraction n'a de conséquence que si elle est repérée. Pas de karma caché.

```
VÉRIFICATION D'INFRACTION — déclenchée par événement (EventBus, E.12) :
  creature_killed, item_possessed (ramassage/craft), item_sold,
  border_crossed (E.24/déplacement inter-royaume avec cargo) →
  lookup dans data/kingdoms/{royaume_local}.json → laws[] filtré par
  type+target correspondant à l'événement.
  Coût : une lookup dictionnaire par événement concerné, négligeable.

DÉTECTION (l'infraction n'a de conséquence QUE si repérée) :
  Réutilise le cône de détection des PNJ à proximité (E.16) : jet
  opposé Discrétion du joueur vs Perception du PNJ témoin le plus
  proche (E.3). Aucun témoin dans le rayon → l'infraction est
  IGNORÉE mécaniquement (pas de log caché, pas de "karma" — cohérent
  avec le principe general de ne pas punir ce qui n'est pas vu).

RÉSOLUTION DE LA CONSÉQUENCE (`laws[].consequence`) :
  "amende:N"        → débit automatique du portefeuille joueur (si
                       insuffisant : confiscation d'objets à la place)
  "confiscation"     → l'objet concerné est retiré de l'inventaire
  "gardes_hostiles"  → les gardes locaux (profil E.16 "garde") gagnent
                       une considération d'urgence "intercepter le
                       contrevenant" — combat ou fuite (E.7-like)
  Royaume sans gardes (anarchie, 14.4) → AUCUNE conséquence structurelle
    possible : la loi ne peut mécaniquement pas s'appliquer.
  Impact secondaire systématique : réputation par royaume (7.2) baisse
    proportionnellement à la sévérité de la loi enfreinte.

DOUANES/TARIFS (import-export) — vérifiées au franchissement de
  frontière avec du cargo (inventaire du joueur ou d'un véhicule,
  E.24) OU à la vente en boutique d'un royaume différent de l'origine
  du bien :
    prix_final = prix_suggere (A.8) * (1 - tariffs[categorie])
    tariff >= 1.0 → vente/import refusés (bien interdit)
  La CONTREBANDE (faire passer un bien taxé/interdit sans déclaration)
  suit exactement le pipeline détection ci-dessus — aucun système
  séparé nécessaire : c'est une infraction "objet" comme une autre.

Génération des lois arbitraires (flavor, 14.4) : au moment de générer
  un royaume, tirage aléatoire pondéré (ex. 15 % de chance) d'ajouter
  0-2 lois absurdes depuis un pool `data/absurd_laws_pool.json` (un
  objet courant + statut illégal + conséquence mineure) — gratuit en
  contenu, mémorable en jeu.
```

**Réparation légale ([[Voie de rédemption]]) :** payer une amende est l'une des voies de remontée de réputation.

**Plantes illégales ([[Plantes]]) :** Belladone — *illégale dans certains royaumes*. **Potions illégales ([[Potions]]) :** Poison de lame — *illégal dans la plupart des royaumes*.

**Information locale ([[L'information comme récompense]]) :** au palier 20-49, un PNJ renseigne *les lois du royaume et leurs sévérités*.

## Liens
- **Dépend de** : [[Gouvernance, lois et diplomatie]], [[Schéma royaume]], [[IA des créatures]], [[Jet de compétence universel]]
- **Alimente** : [[Réputation et relations]], [[Prix suggéré]], [[Véhicules]], [[Voie de rédemption]]
- **Voir aussi** : [[EventBus]], [[Génération des royaumes PNJ]], [[Commerce et boutiques]], [[Plantes]], [[Potions]], [[Compétences — liste]], [[L'information comme récompense]]
