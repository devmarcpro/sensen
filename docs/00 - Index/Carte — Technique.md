---
aliases: ["Carte — Technique", "Carte Technique"]
tags: [index, carte]
domaine: index
statut: décidé
etape: 0
---

L'architecture Godot et la stratégie de performance. 16 notes.

> [!warning] C'est le dossier le plus touché par l'**héritage voxel** : la plupart des notes de performance et plusieurs décisions d'architecture décrivent encore l'ancien moteur. Lire [[Héritage voxel — audit]] avant de s'appuyer sur ce dossier.

**Les fondations**
- **[[Data-driven design]]** — *les systèmes réagissent aux tags présents, pas à des identifiants codés en dur.* Le principe qui permet l'interaction inter-systèmes.
- **[[Localisation]]** — contrainte du jour 1. *Trivial au jour 1, cauchemar à retrofit.*
- **[[Arborescence du projet]]** — autoloads, data, systems, scenes.
- **[[Décisions d'architecture]]** — les huit décisions qu'on ne peut pas rattraper après coup.
- **[[Simulation à ticks]]** — *jamais `_process(delta)` pour la logique de jeu.*
- **[[EventBus]]** — la table des signaux, et la règle de découplage universelle.
- **[[Résolveur de modificateurs]]** — *aucun système ne modifie jamais une valeur en dur.*
- **[[Sauvegarde]]** — différentielle : seuls les chunks modifiés sont écrits.
- **[[Réseau]]** — host autoritaire, le client envoie des intentions. Vaut dès le solo.
- **[[Écrans d'interface]]** — la liste de référence.

**La performance (Annexe G — fait autorité)**
- **[[Budgets de performance]]** — les cibles chiffrées.
- **[[Optimisation — principes]]** — *mesurer avant d'optimiser, mais architecturer pour l'optimisation dès le jour 1.*
- **[[Voxels — mémoire et meshing]]** — le LOD de distance est LA parade au coût du 1px.
- **[[Éclairage]]** — propagation incrémentale ; le cycle jour/nuit module en shader, donc ne coûte rien.
- **[[Génération procédurale — performance]]** — le terrain spectaculaire coûte le prix du terrain plat.
- **[[Entités et pathfinding — performance]]** — meshes partagés : 100 villageois = ~6 meshes.
- **[[Simulation du monde — performance]]** — la timer wheel : 10 000 cultures = coût nul.
- **[[Réseau et sauvegarde — performance]]**
- **[[Ordre de vérification]]** — *un critère raté = on optimise AVANT d'empiler le système suivant.*

**Les risques**
- **[[Risques majeurs]]** — sept risques, dont un levé par la direction tactique.

## Liens
- **Voir aussi** : [[Sensen — Index général]], [[Contraintes permanentes]], [[Ordre de construction]], [[Carte des dépendances]]
