# Guide Git — TalkTome

Git garde un historique de chaque version de votre code. Vous pouvez toujours revenir en arrière si une modification ne vous plaît pas.

Toutes les commandes ci-dessous s'exécutent dans un terminal PowerShell, après :
```powershell
cd "C:\chemin\vers\votre\dossier\de\projet"
```

## 1. Voir ce qui a changé

```bash
git status
```
Liste les fichiers modifiés depuis le dernier point de sauvegarde ("commit").

```bash
git diff
```
Montre le détail ligne par ligne de ce qui a changé.

## 2. Sauvegarder un état qui vous plaît (commit)

Après une modification que vous approuvez (par exemple après avoir testé une nouvelle fonctionnalité sur votre téléphone) :
```bash
git add -A
git commit -m "Description courte du changement"
```
Ça crée un point de restauration. Faites ça régulièrement — après chaque fonctionnalité qui marche.

## 3. Annuler une modification qui ne vous plaît pas

**Cas A — Vous n'avez pas encore sauvegardé (pas de commit) le changement problématique :**
```bash
git checkout -- .
```
Remet tous les fichiers à l'état du dernier commit. ⚠️ Perd les changements non sauvegardés, sans retour possible.

**Cas B — Vous avez déjà commité, mais vous voulez annuler le dernier commit :**
```bash
git revert HEAD
```
Crée un nouveau commit qui annule le précédent (le plus sûr — garde l'historique intact).

**Cas C — Vous voulez revenir loin en arrière, à un commit précis :**
```bash
git log --oneline
```
Affiche la liste des commits avec leur identifiant (ex: `b49ce97`). Puis :
```bash
git reset --hard <identifiant_du_commit>
```
⚠️ Ceci est destructif — tout ce qui a été fait après ce commit est perdu. Demandez-moi avant si vous n'êtes pas sûr.

## 4. Voir l'historique

```bash
git log --oneline
```
Liste condensée de tous les points de sauvegarde, du plus récent au plus ancien.

## 5. Comment je vais travailler avec vous désormais

Avant chaque modification un peu risque ou expérimentale, je vous proposerai de faire un commit de l'état actuel d'abord (`git commit`). Comme ça, si le résultat ne vous plaît pas, on peut revenir en arrière avec `git revert` ou `git reset` sans perdre de travail.

## Résumé — les 3 commandes à retenir

| Je veux... | Commande |
|---|---|
| Sauvegarder ce qui marche | `git add -A` puis `git commit -m "message"` |
| Annuler le dernier changement sauvegardé | `git revert HEAD` |
| Voir l'historique | `git log --oneline` |
