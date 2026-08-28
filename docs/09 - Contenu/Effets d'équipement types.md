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

> [!success] Codé le 2026-08-28 — les mécaniques et les tags sont branchés
> `Etres.recalculer` collecte les affixes `passif_mecanique` dans `e.mecaniques` (mécanique → paramètres). Branchés : **`vitesse_deplacement`** (+5..15 % : les ticks de pas ÷ (1 + pct/100)), **`regen_sante`** (+50..100 % : hors combat, **1 PV toutes les `200 × 100 / pct` ticks** — décision : il n'y a pas de régénération de base, l'affixe *est* la régénération ; `passif_regen` n'est plus inerte), **`surchauffe_mult`** (×0,6..0,9 sur les dégâts de surchauffe), **`capacite_poids`** (+10..40, nouvel affixe `passif_poids`, anneau/amulette/cuirasse), **`faim_vitesse`** (×0,7..0,9, nouvel affixe `passif_faim`). Tags : **`pas_silencieux`** (les IA ne détectent le porteur qu'à portée × 0,7), **`immunite_poison`** (tout statut tagué `poison` est refusé), **`detection_tresors`** (`Simulation.tresors_detectes(e)` : les contenants à 10 tuiles, dessinés en or par le client même hors de vue). `respiration_aquatique` attend la jauge de souffle (Eau et liquides).

## Liens
- **Dépend de** : [[Effets d'équipement passifs]], [[Compétences — liste]], [[Stats de personnage]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Monstres rares]], [[Génération de donjon]]
- **Voir aussi** : [[Génération par couches de bruit]], [[Cycle jour-nuit et sommeil]], [[Eau et liquides]], [[Armures et poids porté]], [[Faim]], [[Mana]], [[Quêtes et guildes]]
