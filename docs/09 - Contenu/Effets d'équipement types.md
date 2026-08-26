---
aliases: ["F.7", "Annexe F.7", "Effets d'équipement types", "Pools d'effets", "grant_tag pool"]
tags: [contenu, objets, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 3
---

Les pools d'effets par slot, pour le générateur de loot.

*Pools par slot pour le générateur : anneaux/amulettes tirent **1-2 effets**, armes/armures **0-1**.*

**skill +2..+6 :** Méditation, Esquive, Discrétion, Négociation, Minage, Forge, Leadership, Dressage, Lecture, Athlétisme

**stat +1..+3 :** les 6 stats ([[Stats de personnage]])

**mechanic :** `capacite_poids` +10..+40 · `faim_vitesse` ×0.7..0.9 · `surchauffe_mult` ×0.6..0.9 · `vitesse_deplacement` ×1.05..1.15 · `regen_sante` +50..100 %

**grant_tag :** `detection_filons`, `detection_tresors` (chasseurs de trésor !), `vision_nocturne`, `respiration_aquatique`, `pas_silencieux`, `immunite_poison`

**Format des effets :** [[Effets d'équipement passifs]] (4 cibles : stat, skill, mechanic, grant_tag).

**Révélation des couches de bruit ([[Génération par couches de bruit]]) :** `detection_filons`/`detection_tresors` sont l'un des moyens de révéler les couches cachées (mana, ressources).

**Vision nocturne ([[Cycle jour-nuit et sommeil]]) :** annule le malus de vision nocturne du porteur.

**Respiration aquatique ([[Eau et liquides]]) :** immunité à la jauge de souffle.

**Budget renforcé :** trésors/artefacts 2-3 effets ([[Trésors et artefacts]]) · monstres rares 3-4 effets ([[Monstres rares]]).

**Infusion ([[Loot — affixes, gemmes et rareté]]) :** 1 max par objet, pose un `grant_tag` utilitaire (vision nocturne, pas silencieux) — utile, jamais transformateur.

**Peuplement des donjons ([[Génération de donjon]]) :** les contenants de loot tirent dans ces tables standards, modulées par la formule de profondeur.

## Liens
- **Dépend de** : [[Effets d'équipement passifs]], [[Compétences — liste]], [[Stats de personnage]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Monstres rares]], [[Génération de donjon]]
- **Voir aussi** : [[Génération par couches de bruit]], [[Cycle jour-nuit et sommeil]], [[Eau et liquides]], [[Armures et poids porté]], [[Faim]], [[Mana]], [[Quêtes et guildes]]
