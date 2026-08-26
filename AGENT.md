# Prompt — développement autonome de Sensen

> Copier tout ce qui suit dans une nouvelle session d'agent. Ce fichier est versionné : le mettre à jour si les règles changent.

---

Tu travailles sur **Sensen** (森森), un roguelike tactique en monde-planète continu, vue isométrique sur grille, combat en **action-time à ticks**. Dépôt : `c:\Sensen`, remote `https://github.com/devmarcpro/sensen`. Moteur : **Godot 4.6.3**, binaire local : `C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe`.

**Ta mission : développer le jeu en autonomie**, incrément par incrément, en suivant l'ordre de construction déjà décidé. Tu ne conçois pas le jeu — il est déjà entièrement conçu. Tu l'implémentes.

## La source de vérité

Le design complet vit dans `docs/` — un coffre Obsidian de 272 notes atomiques. **Tout est déjà décidé et chiffré** : formules, coûts en ticks, schémas JSON, catalogues. Avant de coder quoi que ce soit, lis les notes concernées. Points d'entrée :

- `docs/00 - Index/Sensen — Index général.md` — la carte du coffre
- `docs/00 - Index/Ordre de construction.md` — **la séquence à suivre** (11 étapes, chacune jouable et jugeable)
- `docs/00 - Index/Vers la production.md` — l'état d'avancement, à tenir à jour
- `docs/00 - Index/Contraintes permanentes.md` — **5 règles non négociables**, à relire avant chaque système
- `docs/03 - Combat/Prototype de combat — spécification.md` — l'étape 0, spécification exécutable

Une **démo 0** existe déjà (`godot/scenes/demo/`) : grille iso 24×24 avec relief, A* aux coûts de pente, horloge à ticks, un loup hostile. C'est le point de départ — étends-la vers le prototype de combat au lieu de repartir de zéro.

## Les règles de travail

1. **Ne réinvente rien.** Si une note donne une formule, c'est cette formule. Si tu crois qu'une note se contredit avec une autre, la plus récente fait foi (cherche les callouts datés) ; signale le conflit dans ton rapport.
2. **Si un détail manque réellement** : tranche avec la solution la plus simple cohérente avec le design, puis **écris la décision dans la note concernée** (callout daté `> [!success] Décidé le <date>`) avant de la coder. Le code ne doit jamais être en avance sur les notes.
3. **Data-driven strict** : aucune valeur de gameplay en dur dans le code. Tout vient de `godot/data/*.json` (un fichier = une entrée, `_template.json` par dossier, validation de schéma au boot, bloquante en debug). Les 176 modules, les exemples de PNJ et d'objets y sont déjà.
4. **Le joueur n'est pas un type à part** : même schéma d'entité que tout être, le contrôle est un attribut. Aucun `if (espèce == x)` — on teste la présence d'un bloc, jamais le type.
5. **Aucun asset** : tout se dessine en polygones/couleurs par code. Les vrais sprites viendront plus tard ; la construction donne la forme, le matériau la teinte.
6. **GDScript typé**, commentaires en français, sobres, dans le style des fichiers existants. Pas de GDExtension/Rust avant qu'un profiling le justifie.

## La boucle de validation — après CHAQUE incrément

```powershell
# 1. le projet tourne sans erreur (120 frames headless)
& "C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe" --headless --path C:\Sensen\godot res://scenes/demo/main.tscn --quit-after 120

# 2. le coffre est intègre (liens, frontmatter, comptages)
python C:\Sensen\tools\check_vault.py

# 3. commit + push (messages en français, décrivant le POURQUOI)
git add -A ; git commit ; git push origin main
```

Un incrément n'est terminé que si les trois passent. Si tu ajoutes des scènes de test, mets-les dans `godot/scenes/tests/` et fais-les tourner en headless avec des `assert` — c'est ta seule harnais de test, sers-t'en.

## Ce que tu ne peux pas juger seul

Le **game feel** (lisibilité de l'iso, vitesse perçue, clarté des télégraphes) exige un œil humain. Quand un incrément en dépend : termine-le, note précisément **quoi regarder et quelle question trancher** dans ton rapport et dans `Vers la production.md`, et passe à l'incrément suivant qui n'en dépend pas. Ne bloque jamais en attente d'une validation visuelle.

## L'ordre de travail

Suis `Ordre de construction.md`. En résumé : **étape 0 = le prototype de combat isolé** (sa spécification liste ses propres jalons internes — grille, garde, zones de coup, Wu Xing, jauge de chaîne, modules, IA, fuite). Rien d'autre ne commence tant que l'étape 0 n'est pas complète. Chaque étape suivante n'est entamée que quand la précédente tourne.

À chaque étape terminée : coche-la dans `Vers la production.md`, mets à jour le `README.md` si le lancement change, commit, push.

## Interdits

- Créer des fichiers `.obsidian/` — jamais.
- Réseau/multijoueur, sauvegarde, génération de monde complet : **pas avant leur étape**.
- Refactoriser le design dans les notes — tu peux *compléter* (combler un trou, dater une décision), jamais *réécrire* une décision existante sans instruction humaine.
- Dépendances externes (addons, plugins) sans nécessité démontrée.
