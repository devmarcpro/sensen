---
aliases: ["E.24", "Annexe E.24", "Véhicules", "Bateaux", "Charrette"]
tags: [objets, véhicules, décidé, héritage-voxel]
domaine: objets
statut: décidé
etape: 6
---

> [!warning] Héritage voxel
> « Σ durete des voxels » et le modèle sculpté voxel sont héritage : les stats dérivent désormais du modèle **pixel art** ([[Tables de sculpture]]). L'entité rigide, les blocs fonctionnels, le pilotage en ticks et le voyage rapide survivent ; « 1 bloc de dénivelé » se lit « 1 niveau de hauteur ».
> — Classement complet : [[Héritage voxel — audit]].

Un véhicule est une entité rigide, pas un morceau de monde qui bouge — et la seule exception à la règle forme-libre de la sculpture.

```
NATURE — un véhicule est une ENTITÉ RIGIDE : le modèle sculpté (table
véhicules, 13) devient un objet mobile unique, façon grosse monture.
Le monde voxel n'est PAS emporté : collision par boîte englobante +
échantillonnage de la coque contre le terrain. Beaucoup plus simple
et robuste (réseau compris) que des "blocs qui bougent".

TYPES AU LANCEMENT — terrestres et navals ; aériens = extension future
(l'architecture entité-rigide les permettra sans refonte).
Fonctionnalités (B.3.1, kind "vehicule") :
  Charrette (terrestre, cargo)         Char à voile (terrestre, rapide)
  Draisine mécanique (terrestre)       Barque (naval, petit)
  Voilier (naval, cargo + passagers)
PROPULSION : mécanique/voiles — autonome, pas de traction animale.
  Le vent (direction globale par cellule, dérivée du bruit météo)
  module la vitesse des véhicules à voiles (naviguer contre le vent
  = lent ; compétence Navigation réduit le malus).

BLOCS FONCTIONNELS À LA SCULPTURE — pendant la sculpture, le joueur
place des blocs spéciaux (extension des marqueurs 12.1, ici visibles) :
  Siège de pilote (obligatoire, 1)   Sièges passagers (0-N)
  Gouvernail/timon (obligatoire)     Coffres intégrés (cargo)
  Mât+voile (véhicules à voiles — surface de voile ∝ vitesse)
  Roues (terrestres : >= 2 requis, matériau des roues → friction)
La VALIDATION vérifie les requis de la fonctionnalité choisie —
c'est la seule "contrainte de forme" du jeu (exception assumée à la
règle forme-libre de la section 13, car fonctionnelle et lisible).

STATS DÉRIVÉES (A.4/A.4.5, aucune stat nouvelle de matériau) :
  PV_vehicule = Σ durete des voxels * qualité
  vitesse = base(fonctionnalité) * f(poids total, surface de voile
            ou taille des roues) — matériaux légers = véhicule vif
  capacité de cargo = Σ volume des coffres intégrés
  flottaison (navals) : moyenne pondérée flottabilite >= 50 (A.4.5),
  tirant d'eau ∝ densité — un voilier blindé de fer coule, doser.
PILOTAGE — monter au siège (interaction) ; contrôles directs façon
monture ; les compagnons/joueurs s'assoient aux sièges passagers.
En mode tactique (5.0) : déplacer le véhicule coûte des ticks comme
une entité (1 case de mouvement = coût f(vitesse)).
TERRAIN — les terrestres franchissent 1 bloc de dénivelé, la pente
raide les arrête (les routes 9.2/friction des pavés prennent leur
sens) ; les navals demandent >= 1 bloc d'eau de profondeur + tirant.
DÉGÂTS — les véhicules encaissent (PV) ; à 0 : épave récupérable
(50 % des matériaux, façon A.11). Pas de dégâts de collision infligés
aux entités percutées au lancement (simplicité), juste poussée.
CARTE DU MONDE — voyager avec un véhicule accélère le voyage rapide
(coût de temps in-game réduit : x0.6 terrestre sur route, x0.5 naval
sur mer) et augmente le cargo transportable en voyage.
SAUVEGARDE/RÉSEAU — une entité standard (E.10/E.11) : position,
modèle référencé, PV, contenu des coffres ; le host est autoritaire.
```

**Craft compositionnel ([[Craft compositionnel]]) :** les véhicules fonctionnaient *déjà* selon ce paradigme (coque + roues + mât) — le craft entier du jeu devient un seul modèle compositionnel.

**Météo ([[Météo]]) :** en tempête, les véhicules à voiles deviennent ingouvernables.

**Douanes ([[Lois et infractions]]) :** le cargo d'un véhicule est vérifié au franchissement de frontière.

## Liens
- **Dépend de** : [[Tables de sculpture]], [[Éditeur de sculpture]], [[Fonctionnalité]], [[Application des stats de matériau]]
- **Alimente** : [[Carte du monde]], [[Craft compositionnel]], [[Lois et infractions]]
- **Voir aussi** : [[Météo]], [[Eau et liquides]], [[Explosions]], [[Quêtes et guildes]], [[Compétences — liste]], [[Sauvegarde]], [[Réseau]]
