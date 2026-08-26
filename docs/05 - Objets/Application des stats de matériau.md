---
aliases: ["A.4.5", "Annexe A.4.5", "Application des stats", "Stats étendues des matériaux"]
tags: [objets, matériaux, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

Comment chacune des 13 stats de matériau entre dans les formules du jeu — et le principe d'équilibrage par profils.

Les 13 stats de matériau ([[Matériaux — 13 stats]]) se transmettent aux objets craftés/sculptés par **moyenne pondérée** (quantités de recette ou comptage de voxels — même mécanisme que la dureté, [[Stats d'un objet crafté]]). La **qualité ne les multiplie PAS** : ce sont des propriétés physiques, pas des performances (seule la dureté → dégâts/protection passe par la qualité, via [[Stats d'armes]]/[[Armures et poids porté]]).

**Principe d'équilibrage (avec 120+ matériaux) :** la différenciation vient de **profils** (chaque matériau excelle quelque part et paie ailleurs — l'opale règne sur le mana mais casse, le jade tient par son élasticité, le basalte résiste mais conduit), pas d'une inflation générale des échelles ; et les **formules sont calibrées pour que ~30 points d'écart se ressentent en jeu** (~20-25 % d'effet). Les paliers serrés de dureté des roches sont VOULUS (stratification [[Stratification verticale]]) — ne pas les écarter.

Effets par défaut dans les formules :
```
Coût en mana d'un module (via l'arme tenue) :
  cout_effectif *= (1 - conductivite_mana_arme / 140)   (max ~-65 %)
  (dénominateur réduit : 30 points d'écart entre deux gemmes ≈ 21 %
  de coût — le choix de la gemme du bâton devient structurant)
Dégâts de foudre reçus :
  *= (0.35 + conductivite_electrique_armure / 77)       (0.35x à 1.65x)
  (courbe élargie : l'armure de cuir vs de fer face à un mage foudre
  n'est plus un détail mais un x3 d'écart)
Résistance chaleur/froid (biomes extrêmes, dégâts élémentaires) :
  degats_subis *= (1 - isolation_armure / 125)   (max -80 %)
  (la laine/fourrure en toundra, le saphir contre le feu : décisifs)
Feu : chance d'ignition d'un bloc/objet exposé = flammabilite / 100
  par exposition ; vitesse de combustion proportionnelle
Chute : degats_chute *= (1 - elasticite_bloc_reception / 150)
Arc/arbalète : degats *= (0.8 + elasticite_bois / 250)  (bois élastique = arc puissant)
Véhicule naval : flotte si moyenne pondérée de flottabilite >= 50
Vitesse de déplacement au sol : *= (0.85 + friction_sol * 0.003)
  bornée [0.85, 1.15] (glace 0 = glissade, pavés 100 = +15 %)
Agriculture : rendement_final = rendement_biome (B.6) * (0.5 + fertilite_sol / 100)
Lumière émise par un bloc/objet : niveau = luminosite / 100 * 15
  (échelle de lumière 0-15 ; un objet lumineux porté éclaire mais
  augmente la détection par les ennemis — malus de Discrétion)
Transparence : transparence >= 50 → le bloc laisse passer lumière et
  regard (fenêtres, serres) — impact meshing : passe de rendu séparée
```

**Usage par la météo ([[Météo]]) :** l'isolation contre la température ressentie, la conductivité électrique pour le ciblage de la foudre (paratonnerre émergent), la flammabilité pour l'ignition spontanée en canicule et l'arrachage des blocs `durete <= 3` en tempête.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Stats d'un objet crafté]]
- **Alimente** : [[Mana]], [[Armure par zone et constructions]], [[Météo]], [[Éclairage]], [[Agriculture et élevage]], [[Véhicules]], [[Eau et liquides]]
- **Voir aussi** : [[Stratification verticale]], [[Qualité d'artisanat]], [[Catalogue matériaux — Gemmes]], [[Risques majeurs]], [[Stats et qualité de l'assemblage]]
