---
aliases: ["E.22", "Annexe E.22", "Eau et liquides", "Liquides", "Eau"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

Un automate cellulaire par blocs, pas une simulation de fluide — et tout ce qui en découle : nage, foudre dans l'eau, bateaux.

```
MODÈLE — automate cellulaire par blocs, PAS de simulation de fluide :
- Un bloc de liquide est SOURCE (niveau 8/8) ou ÉCOULEMENT (niveau 7→1).
- Propagation : un liquide s'écoule vers le bas en priorité (devient
  source de chute), sinon s'étale horizontalement en perdant 1 niveau
  par bloc (portée 7 blocs pour l'eau, 3 pour les liquides visqueux —
  lave, boue, goudron, huile : champ `viscosite` dérivé de la friction).
- Vitesse : mise à jour des blocs liquides actifs tous les 5 ticks
  (eau) / 15 ticks (visqueux) — file de blocs "à recalculer", seuls
  les liquides en mouvement coûtent quelque chose.
- Les sources sont INFINIES en récolte au seau (un lac ne se vide pas
  en le puisant) mais un bloc source détruit/déplacé disparaît.
  Pas de "bassin infini 2x2" : une source ne se duplique jamais
  (différence assumée avec Minecraft, évite les exploits d'eau).
- SUBDIVISION (4.1) : les liquides vivent à la résolution 16px
  UNIQUEMENT — un bloc partiellement subdivisé compte comme solide
  si >= 50 % de son volume est plein, sinon le liquide le traverse.
  (Garde la physique simple ; l'étanchéité fine n'est pas simulée.)

INTERACTIONS (par tags/stats, section 10 + A.4.5) :
- Lave + eau adjacentes → obsidienne (contact source) ou pierre
  (contact écoulement). Lave enflamme les blocs flammabilite > 0
  adjacents ; dégâts de contact 3d6 feu/tour.
- L'eau éteint le statut Brûlure ; nettoie certains statuts de surface.
- Conductivité : la foudre (modules F.2) frappant l'eau se propage à
  toutes les entités dans le volume d'eau connexe (rayon 5) — l'eau
  salée (CÉl 90) étend le rayon à 8.
- Le courant pousse les entités et objets au sol (direction de
  l'écoulement, force faible).

NAGE ET IMMERSION :
- Nager = Athlétisme ; vitesse = f(compétence), le poids porté tire
  vers le fond (surcharge = on coule, largage d'objets possible).
- Souffle : jauge 30 s + Endurance*2 ; à 0 → 1d6 dégâts/tour.
  respiration_aquatique (tag F.7) = immunité.
- Sous l'eau : vision réduite, pas de combat à distance sauf arbalète
  (malus -4), mêlée à -2, feu impossible, foudre déconseillée (cf. plus
  haut — y compris pour le lanceur).
- La pluie (météo par biome, extension future) remplit les cavités
  ouvertes d'1 niveau max — pas d'inondation générale.

BATEAUX (pont vers les véhicules, 13) : un véhicule sculpté flotte si
flottabilite moyenne >= 50 (A.4.5) ; il repose sur la surface des blocs
d'eau et suit le courant s'il n'est pas dirigé. Détail du pilotage :
avec le système véhicules (à spécifier).
Réseau : le host simule, les écoulements sont des mutations de blocs
standard (E.11) — rien de nouveau à synchroniser.
```

**Simplification par la direction tactique ([[Hauteur de terrain ±10]]) :** les fluides coulent — l'eau remplit les creux, la lave descend. E.22 se simplifie en **2D + hauteur** au lieu d'un volume.

**Coût ([[Simulation du monde — performance]]) :** file active uniquement — un lac stable coûte 0.

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Véhicules]], [[Catalogue matériaux — Liquides]], [[Météo]]
- **Voir aussi** : [[Statuts]], [[Modules]], [[Réseau]], [[Simulation du monde — performance]], [[Compétences — liste]]
