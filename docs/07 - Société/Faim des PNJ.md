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

> [!important] 2026-09-04, 14 h — la grande base simulée mangeait deux fois, et ne mangeait pas ce que ses fermiers récoltaient
> Vingt résidents, deux fermiers, douze semaines (`sonde_grande_base`) : **quarante** lignes « affamé » par semaine pour vingt résidents, et trente-cinq baies qui s'entassaient au stock du territoire pendant que tout le monde avait faim. Deux causes. (1) Le repas vivait dans `_recalculer_humeurs`, appelée **deux fois** par semaine — après les maisons bâties, puis au bilan — donc deux repas, ou deux malus. Le repas est désormais une étape à part (`_nourrir_residents`), une fois par semaine, avant le bilan ; `_recalculer_humeurs` lit ce qu'elle a laissé. (2) La note dit « les stocks de nourriture du claim » ; le code ne lisait que les **meubles** garde-manger, jamais `territoire.stocks`, où tombe pourtant la production des fermiers. Le stock du territoire est un garde-manger de fait : un résident y prend une unité de tout consommable à nutrition > 0 quand les meubles sont vides. Priorité aux meubles (ce que le joueur a rangé lui-même), puis le stock.

## Liens
- **Dépend de** : [[Faim]], [[Schéma unifié créature-PNJ]], [[Agriculture et élevage]]
- **Alimente** : [[Habitat des PNJ]], [[Population et exploitation]], [[Abstraction hors-site]]
- **Voir aussi** : [[Meubles]], [[Simulation du monde — performance]], [[IA des créatures]]
