---
aliases: ["A.4.5", "Annexe A.4.5", "Application des stats", "Stats étendues des matériaux"]
tags: [objets, matériaux, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

Comment chacune des 13 stats de matériau entre dans les formules du jeu — et le principe d'équilibrage par profils.

Les 13 stats de matériau ([[Matériaux — 13 stats]]) se transmettent aux objets craftés/sculptés par **moyenne pondérée** (quantités de recette ou comptage de pixels — même mécanisme que la dureté, [[Stats d'un objet crafté]]). La **qualité ne les multiplie PAS** : ce sont des propriétés physiques, pas des performances (seule la dureté → dégâts/protection passe par la qualité, via [[Stats d'armes]]/[[Armures et poids porté]]).

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
Transparence : transparence >= 50 → la tuile laisse passer lumière et
  regard (fenêtres, serres) — impact rendu : passe séparée
```

**Usage par la météo ([[Météo]]) :** l'isolation contre la température ressentie, la conductivité électrique pour le ciblage de la foudre (paratonnerre émergent), la flammabilité pour l'ignition spontanée en canicule et l'arrachage des blocs `durete <= 3` en tempête.

> [!bug] Rattrapé le 2026-09-03 — **six des treize stats étaient décoratives** (designer)
> « Pour l'arc, les stats devraient être affectées par l'élasticité, tu ne penses pas ? » — puis, sur ma première réponse : « t'es sûr que les autres 9 stats sont vraiment utilisées ? »
> **Non.** Cette note donne une formule pour chacune des treize stats, elle est datée et marquée décidée, et **le code n'en lisait que sept**. Une stat qu'on affiche sur la fiche d'un matériau et que rien ne lit est une promesse en l'air : le joueur compare deux bois par leur élasticité et choisit celui qui ne changera rien.
>
> | stat | ce que la note promet | l'état avant le 2026-09-03 |
> |---|---|---|
> | `elasticite` | `degats *= (0.8 + elasticite / 250)` pour l'arc, amortissement des chutes | **jamais lue** |
> | `friction` | vitesse au sol `*= (0.85 + friction × 0.003)` | **jamais lue** |
> | `conductivite_mana` | coût du sort `*= (1 - conductivite / 140)` | **jamais lue** |
> | `luminosite` | lumière émise | lue **sur l'objet**, jamais sur la matière — une lampe taillée dans une matière lumineuse ne brillait pas |
> | `transparence` | `>= 50` laisse passer lumière et regard | lue **sur le contenu de tuile**, jamais sur la matière — un mur de verre arrêtait la lumière comme du granit |
> | `flottabilite` | véhicule naval si moyenne ≥ 50 | jamais lue — **et c'est normal** : il n'y a pas de bateau |
>
> Les cinq premières sont branchées, avec les formules **exactement telles que la note les donne** ; les constantes vivent dans `combat_rules.stats_materiau`. Écart mesuré sur l'arc : de la matière la plus raide à la plus élastique, **×1,46** sur les dégâts.
>
> > [!warning] Et ma première vérification était fausse elle aussi
> > La sonde que j'avais écrite portait la liste des stats « lues » **tapée à la main**. Elle annonçait douze sur treize, et c'est le designer qui a demandé si j'en étais sûr. Deux de plus ne servaient à rien. La sonde **cherche désormais dans le code source** — `stats.get("<stat>")` et ses variantes — et croit ce qu'elle trouve. C'est la huitième fois de la journée qu'une liste écrite à la main ment ; celle-ci, je ne l'avais pas vue venir alors que je venais d'écrire la règle dans l'AGENT.md.

> [!success] Codé le 2026-09-03 — trace ajoutée le 2026-09-04
> Les treize stats de matériau agissent toutes depuis ce jour (six étaient décoratives : élasticité des arcs, friction du sol, conductivité de mana, transparence, luminosité, isolation) — `combat_rules.stats_materiau` porte les formules, `sonde_stats_matiere.tscn` lit le code source pour vérifier que chaque stat est lue quelque part.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Stats d'un objet crafté]]
- **Alimente** : [[Mana]], [[Armure par zone et constructions]], [[Météo]], [[Éclairage]], [[Agriculture et élevage]], [[Véhicules]], [[Eau et liquides]]
- **Voir aussi** : [[Stratification verticale]], [[Qualité d'artisanat]], [[Catalogue matériaux — Gemmes]], [[Risques majeurs]], [[Stats et qualité de l'assemblage]]
