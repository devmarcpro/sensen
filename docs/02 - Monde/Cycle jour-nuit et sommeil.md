---
aliases: ["E.21", "Annexe E.21", "Cycle jour/nuit", "Sommeil", "Nuit"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

La nuit est dangereuse mais favorise la Discrétion ; dormir est un choix avantageux, jamais une corvée.

```
CYCLE — 1 jour in-game = 24 000 ticks (E.1) : aube 5h-7h, jour 7h-19h,
crépuscule 19h-21h, nuit 21h-5h (heures in-game). Lumière ambiante
interpolée ; la nuit, seules les sources locales comptent (luminosite
A.4.5 : torches, lanternes, blocs lumineux — l'éclairage de la base
devient un vrai enjeu de construction).

LA NUIT EST DANGEREUSE :
- Spawns nocturnes : les tables de spawn par biome ont un volet "nuit"
  (créatures nocturnes : loups en chasse, prédateurs embusqués,
  humains hostiles en maraude) ; densité de spawn hostile x2, et
  niveau effectif +10 % de corruption locale (E.20) la nuit.
- Malus de vision : cône de détection réduit pour tous (E.16) — le
  joueur voit moins loin, MAIS les ennemis aussi : la nuit favorise
  la Discrétion (jets +4) autant qu'elle menace. Vision nocturne
  (grant_tag F.7) annule le malus du porteur.
- Les PNJ civils rentrent dormir (routines E.16), villages fermés —
  commerce indisponible la nuit sauf tavernes.

SOMMEIL (lit requis, meuble F.6) :
- Dormir SANS sauter le temps ("se reposer jusqu'à l'aube" désactivé) :
  régén santé/mana x4 pendant le sommeil, buff "Reposé" au réveil
  (+5 % XP pendant 4 h in-game, humeur PNJ +5). Vulnérable pendant
  le sommeil (réveillé par toute attaque).
- SAUTER LA NUIT : dormir 21h-5h avance le temps au matin. Le monde
  est résolu par l'abstraction (E.6) pour la durée sautée : cultures
  poussent, boutiques hors-site vendent, timers avancent — le saut
  n'est jamais gratuit ni exploitable (les raids peuvent frapper
  pendant la nuit sautée et réveillent le dormeur, résolution réelle).
- Pas de privation de sommeil punitive pour le joueur (pas de jauge
  fatigue) — dormir est un choix avantageux, pas une corvée.
MULTIJOUEUR — sauter la nuit déclenche un VOTE (même mécanique que le
mode tactique, E.11) : majorité simple, tous doivent être dans un lit
ou hors combat ; le temps saute pour tout le monde.
```

**Note ([[Action-time à ticks]]) :** la mécanique de **vote** ne subsiste que pour le **saut de nuit**.

**Note ([[Potentiel]]) :** le buff « Reposé » restaure du potentiel (+2 à toutes les stats consommées récemment — [[Progression par l'usage]]).

**Rendu ([[Éclairage]]) :** le cycle jour/nuit module en SHADER (uniform global), pas en re-propagation — changer l'heure ne coûte rien.

## Liens
- **Dépend de** : [[Boucle de tick]], [[Simulation à ticks]], [[Application des stats de matériau]]
- **Alimente** : [[IA des créatures]], [[Potentiel]], [[Abstraction hors-site]], [[Créatures]]
- **Voir aussi** : [[Météo]], [[Dérive de la corruption]], [[Meubles]], [[Éclairage]], [[Multijoueur]], [[Réseau]]
