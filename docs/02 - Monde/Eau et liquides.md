---
aliases: ["E.22", "Annexe E.22", "Eau et liquides", "Liquides", "Eau"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> Modèle réécrit en **2D + hauteur** ([[Hauteur de terrain ±10]]). L'automate par blocs 3D d'origine est archivé (GDD source, historique git).

Un automate cellulaire sur la grille — l'eau remplit les creux du terrain, jamais une simulation de fluide.

```
MODÈLE — automate cellulaire par tuiles, 2D + hauteur (3.6) :
- Une tuile de liquide est SOURCE (niveau 8/8) ou ÉCOULEMENT (niveau 7→1).
- Propagation : un liquide s'écoule d'abord vers la tuile voisine de
  hauteur INFÉRIEURE (il descend le relief et remplit les creux), sinon
  s'étale à hauteur égale en perdant 1 niveau par tuile (portée 7 tuiles
  pour l'eau, 3 pour les liquides visqueux — lave, boue, goudron, huile :
  champ `viscosite` dérivé de la friction).
- Vitesse : mise à jour des tuiles liquides actives tous les 5 ticks
  (eau) / 15 ticks (visqueux) — file de tuiles "à recalculer", seuls
  les liquides en mouvement coûtent quelque chose.
- Les sources sont INFINIES en récolte au seau (un lac ne se vide pas
  en le puisant) mais une tuile source détruite/déplacée disparaît.
  Pas de "bassin infini 2x2" : une source ne se duplique jamais
  (différence assumée avec Minecraft, évite les exploits d'eau).
- Une tranchée creusée sous le niveau d'un lac s'inonde ; un talus
  élevé endigue (3.6 : « inonder la tranchée » est une manœuvre
  tactique voulue).

INTERACTIONS (par tags/stats, section 10 + A.4.5) :
- Lave + eau adjacentes → obsidienne (contact source) ou pierre
  (contact écoulement). La lave enflamme les tuiles flammabilite > 0
  adjacentes ; dégâts de contact 3d6 feu/tour.
- L'eau éteint le statut Brûlure ; nettoie certains statuts de surface.
- Conductivité : la foudre (modules F.2) frappant l'eau se propage à
  toutes les entités dans la nappe d'eau connexe (rayon 5) — l'eau
  salée (CÉl 90) étend le rayon à 8.
- Le courant pousse les entités et objets au sol (direction de
  l'écoulement, force faible).

NAGE ET IMMERSION :
- Nager = Athlétisme ; vitesse = f(compétence), le poids porté tire
  vers le fond (surcharge = on coule, largage d'objets possible).
- Souffle : jauge 30 s + Endurance*2 ; à 0 → 1d6 dégâts/tour.
  respiration_aquatique (tag F.7) = immunité.
- Dans l'eau : vision réduite, pas de combat à distance sauf arbalète
  (malus -4), mêlée à -2, feu impossible, foudre déconseillée (cf. plus
  haut — y compris pour le lanceur).
- La pluie (météo, E.28) remplit les cavités ouvertes d'1 niveau max —
  pas d'inondation générale.

BATEAUX (pont vers les véhicules, 13) : un véhicule flotte si
flottabilite moyenne >= 50 (A.4.5) ; il repose sur les tuiles d'eau
et suit le courant s'il n'est pas dirigé. Détail du pilotage :
avec le système véhicules (E.24).
Réseau : le host simule, les écoulements sont des mutations de tuiles
standard (E.11) — rien de nouveau à synchroniser.
```

**Coût ([[Simulation du monde — performance]]) :** file active uniquement — un lac stable coûte 0. Inchangé.

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Véhicules]], [[Catalogue matériaux — Liquides]], [[Météo]]
- **Voir aussi** : [[Statuts]], [[Modules]], [[Réseau]], [[Simulation du monde — performance]], [[Compétences — liste]], [[Destruction du terrain]]
