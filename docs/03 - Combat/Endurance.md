---
aliases: ["A.6.1", "Annexe A.6.1", "Endurance", "Vigueur"]
tags: [combat, ressource, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Une jauge longue et lente : le combat se gère sur la durée, et récupérer est une décision qui coûte du tempo.

```
Max 100. Longue et lente : le combat se gère sur la durée.
COÛTS : attaque 8 · attaque lourde 18 · déplacement 0
        garde À L'IMPACT : 12 + dégâts/4
RÉGÉNÉRATION : +2 par tick écoulé.
ACTION « ATTENDRE » (5 ticks) : rend 20 d'endurance — la
  récupération est une DÉCISION qui coûte du tempo, pas un
  automatisme.
À ZÉRO : garde impossible, attaques à 60 % de dégâts.
La garde est une POSTURE (2 ticks) qui dure jusqu'à la prochaine
action, et elle est FRONTALE : flanc et dos l'ignorent.
```

**Troisième économie ([[Vocabulaire des modules — six axes]]) :** certains modules ont un `cout_endurance` en plus du `cout_ticks` et du `cout_mana` — *les trois économies coexistent et définissent des archétypes*.

**Affixes liés ([[Loot — affixes, gemmes et rareté]]) :** « à la parade : rend [3-8] endurance » · « garde −[20-40] % d'endurance » · gemme **Ambre** : endurance ou compétence physique.

> [!success] Codé le 2026-09-01 — la compétence **Récupération** (designer)
> « les attaques hors capacités devraient consommer de l'endurance et faire en sorte que la récupération fonctionne bien ». **Vérifié avant de coder** : les attaques la consomment déjà — 8 points pour un coup, 18 pour une attaque lourde, prélevés dans `_frapper_arme`. Ce qui manquait, c'est l'autre moitié : la régénération valait **+2 par tick pour tout le monde**, sans compétence ni progression, alors que le mana avait la sienne (Méditation, qui améliore le jet et gagne de l'XP à chaque rendu). L'endurance a désormais son pendant : **Récupération** ajoute `regen_par_niveau` par niveau au gain par tick, et **s'entraîne en récupérant** — un point d'XP par tranche de ticks, seulement quand le corps a réellement regagné quelque chose, jamais à endurance pleine. Un débutant reprend 2 points par tick, un athlète confirmé le double.


> [!success] Décidé et codé le 2026-09-03 — cette jauge s'appelle **vigueur**, et son maximum suit la **force**
> Le designer a séparé la stat de la monnaie (« sépare bien vigueur et endurance ») : **la stat s'appelle `endurance`** (elle donne les PV et tient la ligne), **la monnaie s'appelle `vigueur`** — c'est elle que cette note décrit. Le « Max 100 » ci-dessus est périmé, et `cout_endurance` est renommé `cout_vigueur` sur tous les modules : `vigueur_max = 60 + force × 4` (`combat_rules.vigueur.max_base`, `max_par_force`), 100 à force 10, la valeur d'avant. La **philosophie des paires** : la force **dépend** de la vigueur (chaque coup la paie) et en porte la réserve ; l'endurance s'en sert **en bonus**, sa propre rareté étant les PV. Les coûts, la régénération, l'action *Attendre*, l'épuisement — tout le reste de la note tient. Les trois monnaies sont posées côte à côte dans [[Structure compétences-modules-slots]] (callouts du 2026-09-03) et la troisième a sa note : [[Sang-froid]].

## Liens
- **Dépend de** : [[Boucle de tick]], [[Action-time à ticks]]
- **Alimente** : [[Garde en posture]], [[Attaque lourde et télégraphe]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Mana]], [[Vocabulaire des modules — six axes]], [[Sorts cataclysmiques]], [[Loot — affixes, gemmes et rareté]]
