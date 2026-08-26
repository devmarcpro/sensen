---
aliases: ["Ouvert — Saisons", "Saisons"]
tags: [ouvert, monde, décidé-par-défaut]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] RENVERSÉ le 2026-08-26 par l'Annexe H
> Ce défaut (« non incluses ») est **caduc** : l'élevage rend les saisons load-bearing. Voir [[Décision — Saisons activées à l'étape 10]]. Le raisonnement ci-dessous est conservé comme trace — il disait *« la question ne peut pas se trancher avant d'avoir joué la boucle agricole »*, et c'est bien le contenu de cette boucle qui l'a tranchée.

> [!success] Défaut d'origine (caduc)
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** activer ou non les **saisons** — gros impact sur la boucle agricole.

**Ce qui est posé ([[Météo]]) :** *saisons non incluses pour l'instant ; la génération temporelle est conçue pour accueillir une modulation saisonnière plus tard (multiplier le bruit temporel par une courbe annuelle) — question ouverte, gros impact agriculture si activé.*

**Statut dans l'état du document ([[Décisions fondatrices]]) :** classé dans *« reste ouvert, par nature »* — **après playtest de la boucle agricole**.

**L'extension naturelle côté Wu Xing ([[Wu Xing hors combat]]) :** *saisons alignées sur les éléments (si [[Météo]] les active un jour)* — le Wu Xing daoïste associe traditionnellement chaque élément à une saison, ce qui en ferait une extension cohérente avec [[Identité visuelle chinoise]].

**Ce qui en dépend :** [[Agriculture et élevage]] au premier chef (cycles de culture, rendements variables dans l'année), la disponibilité des matériaux météorologiques ([[Catalogue matériaux — Météorologiques]] : Glace, Neige), et le gel des lacs ([[Météo]] : *les lacs gelés ouvrent des raccourcis saisonniers*).

**Coût technique :** faible — *multiplier le bruit temporel par une courbe annuelle*. L'architecture les accueille déjà.

## Le défaut : pas de saisons au lancement

**Décision confirmée : non incluses.** L'architecture les accueille (multiplier le bruit temporel par une courbe annuelle — [[Météo]]), le calendrier existe (**1 an = 120 jours in-game**, [[Âge des PNJ]]), mais **rien n'est activé**.

**Pourquoi c'est un défaut sûr :** activer les saisons change la boucle agricole ([[Agriculture et élevage]]) — un système qui n'existera pas avant l'étape 10. La question ne peut pas se trancher avant d'avoir joué cette boucle ; la trancher maintenant serait deviner.

**Si activé plus tard :** courbe annuelle sur `temperature`, 4 saisons de 30 jours, alignées sur les éléments du Wu Xing (printemps→Bois, été→Feu, fin d'été→Terre, automne→Métal, hiver→Eau — l'attribution daoïste traditionnelle, [[Identité visuelle chinoise]]).

## Liens
- **Dépend de** : [[Météo]], [[Agriculture et élevage]]
- **Alimente** : [[Wu Xing hors combat]], [[Catalogue matériaux — Météorologiques]]
- **Voir aussi** : [[Décisions fondatrices]], [[Identité visuelle chinoise]], [[Génération par couches de bruit]]
