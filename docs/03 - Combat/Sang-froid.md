---
aliases: ["Sang-froid", "Troisième monnaie"]
tags: [combat, ressource, formule, décidé]
domaine: combat
statut: décidé
etape: 10
---

La troisième monnaie, et l'inverse des deux autres : elle ne se gagne pas en agissant, elle se gagne en tenant sa position.

```
Max : 20 + dextérité × 3   (combat_rules.sang_froid.max_base, max_par_dexterite)
PROPRIÉTAIRE : la dextérité — feintes, désarmements, empoignes, tout son combat la paie.
INVITÉE : la perception — visée, point faible, lecture du geste, aux aguets : de l'information.
RÉGÉNÉRATION : hors combat, +1 par tick ; EN combat, seulement si l'être est
  immobile depuis 6 ticks (`seuil_ticks`) — celui qui se replace perd son
  sang-froid, celui qui tient sa ligne le construit.
À VIDE : dépenser se paie en PV, × 2 (`epuisement_mult`) — comme la surchauffe
  du mana et l'épuisement de la vigueur.
```

> [!success] Décidé et codé le 2026-09-03 (designer : « perception et dextérité ensemble »)
> Les deux monnaies existantes étaient déjà deux **comportements** : la vigueur revient à 2 par tick et limite le *rythme* d'un échange ; le mana revient cent soixante fois plus lentement et limite le *budget* d'un étage. Une troisième monnaie n'avait d'intérêt que si elle apportait un troisième comportement. Le sang-froid ne dit ni combien ni quel budget : il dit **quand** on peut se permettre d'agir. C'est le tireur qui retient son souffle, et c'est ce qui donne enfin un prix à la vitesse de la dextérité — la stat la plus rapide est celle qui dépense le plus vite.
> Le compteur d'immobilité est celui que la canalisation et Pied ferme lisent déjà (`immobile_depuis`) : un seul pour tout le jeu. La barre est la quatrième du HUD, en gris-bleu ; elle apparaît aussi à la création et sur la feuille.

## Liens
- **Dépend de** : [[Boucle de tick]], [[Action-time à ticks]]
- **Alimente** : [[Structure compétences-modules-slots]]
- **Voir aussi** : [[Mana]], [[Endurance]], [[Synthèse — les six voies, les monnaies et les modules]]
