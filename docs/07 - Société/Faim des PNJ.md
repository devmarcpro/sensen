---
aliases: ["E.15", "Annexe E.15", "Faim des PNJ", "Garde-manger"]
tags: [société, survie, décidé]
domaine: société
statut: décidé
etape: 10
---

Les PNJ ont la même jauge de faim que le joueur, mais se nourrissent seuls — pénalité, jamais gestion punitive.

Les PNJ résidents ont la même jauge de faim que le joueur (même système, [[Schéma unifié créature-PNJ]] oblige), mais se nourrissent SEULS depuis les stocks de nourriture du claim (conteneurs marqués "garde-manger"). Stock vide → malus d'humeur et de productivité (pas de mort de faim des PNJ : pénalité, pas de gestion punitive). Cela raccorde l'agriculture ([[Agriculture et élevage]]) à la boucle royaume : les champs nourrissent la population qui exploite le territoire.

*(Proposition validée par défaut — cf. décision de [[Agriculture et élevage]].)*

**Meuble concerné ([[Meubles]]) :** Garde-manger — stock nourriture PNJ.

**Effet de l'humeur ([[Habitat des PNJ]]) :** la productivité des jobs est multipliée par `humeur/100 × 1.5` borné [0.4, 1.2] — l'humeur est LE levier de rendement.

**Timers ([[Simulation du monde — performance]]) :** la faim des PNJ ne tourne pas par tick — timer wheel globale.

> [!success] Codé le 2026-08-28
> Chaque semaine, chaque résident mange **une unité** prise dans les **garde-manger** du territoire (fenêtre chargée ; tout consommable à nutrition > 0, une unité par pile) ; garde-manger vide → **humeur −10** (`combat_rules.royaume.faim_pnj`) et journal. Pas de jauge par tick pour les PNJ : une seule échéance hebdomadaire.

## Liens
- **Dépend de** : [[Faim]], [[Schéma unifié créature-PNJ]], [[Agriculture et élevage]]
- **Alimente** : [[Habitat des PNJ]], [[Population et exploitation]], [[Abstraction hors-site]]
- **Voir aussi** : [[Meubles]], [[Simulation du monde — performance]], [[IA des créatures]]
