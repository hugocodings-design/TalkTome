# Guide — Créer une clé API Google Cloud pour TalkTome

## 1. Ouvrir la Console Google Cloud

```
https://console.cloud.google.com/apis/credentials
```
(sélectionnez votre projet en haut de la page — connectez-vous avec le même compte Google que d'habitude)

## 2. Créer la clé

1. Cliquez **"+ CREATE CREDENTIALS"** (en haut) → **"API key"**
2. Une clé est générée immédiatement — **copiez-la** (vous en aurez besoin après)
3. Cliquez **"EDIT API KEY"** (ou l'icône crayon) pour la configurer avant de fermer la fenêtre

## 3. Restreindre la clé (important — ne sautez pas cette étape)

### Restriction d'application
Sous **"Application restrictions"**, sélectionnez **"Android apps"**, puis **"+ Add package name and fingerprint"** :

| Champ | Valeur |
|---|---|
| Package name | `com.hugocodings.talktome` |
| SHA-1 certificate fingerprint | `74:6F:B0:A2:1B:41:62:D5:41:AA:38:26:21:62:9F:C6:C4:CE:4E:75` |

⚠️ Cette empreinte correspond à votre clé de signature **debug** (celle utilisée par `flutter run`). Si vous publiez un jour l'app sur le Play Store avec une clé de signature différente (release), il faudra ajouter une deuxième entrée avec la nouvelle empreinte.

### Restriction d'API
Sous **"API restrictions"**, sélectionnez **"Restrict key"**, puis cochez uniquement :
- ✅ **Cloud Text-to-Speech API**

Ne laissez **aucune** autre API cochée — cette clé ne doit servir qu'à ça.

## 4. Sauvegarder

Cliquez **"SAVE"** en bas. La restriction peut prendre **quelques minutes** avant d'être active.

## 5. Me donner la clé

Copiez la clé (commence par `AIza...`) et collez-la dans le chat. Je l'intégrerai dans le code de l'app — elle ne sera **jamais** commitée en clair dans Git (fichier de config exclu, comme vos autres identifiants).
