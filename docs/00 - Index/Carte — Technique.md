---
aliases: ["Carte — Technique", "Carte Technique"]
tags: [index, carte]
domaine: index
statut: décidé
etape: 0
---

L'architecture Godot et la stratégie de performance. 16 notes.

> [!note] Ce dossier était le plus touché par l'**héritage voxel**. Nettoyé le 2026-08-26 : les notes corrigibles sont réécrites (texte d'origine en annexe historique), les conflits restants ont chacun leur proposition à valider — [[Héritage voxel — audit]].

**Les fondations**
- **[[Data-driven design]]** — *les systèmes réagissent aux tags présents, pas à des identifiants codés en dur.* Le principe qui permet l'interaction inter-systèmes.
- **[[Décision — Pipeline de contenu]]** — le pipeline concret : un fichier JSON par entrée, templates, validation au boot, F5. *Ajouter du contenu = ajouter un fichier.*
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
- **[[Décision — Structure de données de la grille]]** — le LOD de distance est LA parade au coût du 1px.
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
