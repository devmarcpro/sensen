---
aliases: ["Profils de PNJ", "F.3 humains", "PNJ humains", "Profils"]
tags: [contenu, êtres, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

> [!success] Créé le 2026-08-26
> Sort les humains du bestiaire. Un forgeron n'est pas une espèce — c'est une **combinaison** des trois axes ([[Les trois axes — race, classe, fonction]]). Le bestiaire ne garde que les races animales ([[Créatures]]).

**Un profil de PNJ n'est pas une entrée de catalogue : c'est un tirage.** race × classe × fonction × role — et le monde s'en charge.

## Pourquoi ce n'est plus une liste

L'ancien F.3 énumérait 18 « créatures » humaines (villageois, forgeron, bandit, roi…). Chacune était en réalité **la même race** avec un métier différent. Les décrire comme des espèces obligeait à écrire une fiche par métier — et à en écrire une nouvelle à chaque nouveau métier.

Désormais, un PNJ **se génère** :

```
race     ← culture dominante du royaume (Génération des royaumes PNJ)
classe   ← tirée dans le pool de sa fonction (Talents de classe : classes_possibles)
fonction ← poste vacant du village, ou rôle du POI (Fonctions)
role     ← sa place vis-à-vis du joueur (Rôles de l'être)
niveau   ← corruption locale + fonction (Dérive de la corruption)
```

**Ajouter un métier au monde = ajouter une fonction, pas une créature.**

## Les profils de lancement

Ce sont des **presets** — des combinaisons nommées pour la génération et le débogage, pas des espèces. Toutes les valeurs de l'ancien F.3 sont conservées.

### Civils (villages, villes)

| Profil | Race | Classe | Fonction | Role | Nv | Recrutable | Notes |
|---|---|---|---|---|---|---|---|
| Villageois | humain | Le Vent | oisif | résident | 3 | relation 60 | postes vacants au choix |
| Fermier | humain | Le Vent | fermier | résident | 3 | relation 55 | agriculture 15 |
| Forgeron | humain | **La Braise** | artisan | résident | 6 | relation 65 | forge 25 |
| Marchand ambulant | humain | **La Balance** | commerçant | résident | 5 | relation 70 | négociation 20 ; caravanes inter-villages ([[IA des créatures]], pathfinding global) |
| Garde de village | humain | **Le Sabre** | garde | garde | 12 | relation 75 | |
| Prêtre de sanctuaire | humain | **La Paume** | dirigeant | résident | 8 | relation 80 | ressuscite les compagnons ([[Compagnons]]) |
| Maître de guilde | humain | *(variable)* | dirigeant | résident | 20 | **jamais** | |
| Érudit | humain | Le Souffle | oisif | résident | 4 | relation 60 | lecture 30 |
| Tavernier | humain | La Balance | commerçant | résident | 5 | relation 65 | |
| Chasseur de village | humain | **La Trace** | herboriste | résident | 9 | relation 60 | arc 18, dressage 12 |
| Nomade | humain | La Balance | commerçant | sauvage | 9 | relation | marchand itinérant du désert |
| Roi / Reine | humain | *(variable)* | dirigeant | résident | 25 | dressage DD très élevé | **capturable** ([[Population et exploitation]]) |

### Hostiles

| Profil | Race | Classe | Fonction | Role | Nv | IA | Notes |
|---|---|---|---|---|---|---|---|
| Bandit | humain | Le Sabre | aventurier | sauvage | 10 | hostile | **se rend si dominé** |
| Chef de bande | humain | Le Sabre | aventurier | sauvage | 16 | hostile | camps ([[Carte du monde]]) · **élite : jauge de chaîne** ([[Décision — Chaîne côté ennemis]]) |
| Braconnier | humain | La Trace | aventurier | sauvage | 8 | hostile si surpris | |
| Pillard | humain | Le Sabre | aventurier | sauvage | 12 | assaillant | raids ([[Raids et menaces]]) |
| Déserteur | humain | Le Sabre | aventurier | sauvage | 11 | hostile | |
| Ermite | humain | **Le Souffle** | oisif | sauvage | 14 | neutre → hostile si dérangé | relation 85 ; donjons et ruines — gardien humain des trésors · **élite** |

*Les autres races jouables ([[Races]] : Elfe, Nain) tirent les mêmes profils — un forgeron nain est `nain · La Braise · artisan`. La race dominante du royaume décide ([[Génération des royaumes PNJ]]).*

## Ce que ça change concrètement

- **Les classes cachées deviennent trouvables.** Un PNJ à fonction `aventurier` peut tirer **Le Passeur** (≈ 2 %, [[Talents de classe]]) — c'est ce qui rend son apprentissage possible.
- **Le portefeuille suit la fonction**, plus l'espèce ([[Barèmes économiques]] : villageois 30, marchand 300, maître de guilde 2000, roi 15000).
- **Les élites sont un flag**, pas un profil : `chain_gauge: true` sur Chef de bande et Ermite.
- **Le vieillissement, la succession et l'élevage** tournent sur tous ces PNJ sans distinction ([[Blocs de l'être]] : *aucun test d'espèce*).

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Schéma créature]], [[Fonctions]], [[Talents de classe]]
- **Alimente** : [[Génération des royaumes PNJ]], [[Villages PNJ — repeuplement et décimation]], [[Génération de donjon]], [[Barèmes économiques]]
- **Voir aussi** : [[Créatures]], [[Rôles de l'être]], [[Décision — Chaîne côté ennemis]], [[IA des créatures]], [[Population et exploitation]]
