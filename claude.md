# TalkTome — lecteur de livres avec voix IA locales

## Brand identity
- **App name:** TalkTome ("a tome that talks" / "talk to me")
- **Android package ID:** `com.hugocodings.talktome` (permanent once published on Google Play)
- **Mascot:** Tomy — a thick purple grimoire with mystic runes, eyes and a mouth, wearing his red ribbon bookmark (signet) like a cape. Playful little hero; he's the one who will guide users through tutorials.
- **Theme direction:** "Mystic night" — deep purple/indigo, soft gold accents, red reserved for the signet and key actions. Dark-first.

## Ce qu'est le projet
Application Flutter (Android, iPhone) : on importe des livres (PDF, EPUB, pages web, pages scannées) et on les écoute lus par des voix IA. Tout fonctionne sur le téléphone, sans API payante :
- **Voix IA** : sherpa-onnx (Kokoro, Piper), modèles dans `<support>/tts_models/<dossier>`.
- **Dictionnaire** : base Wiktionary hors ligne (`<support>/dict/dict_<langue>.db`) + sens du mot dans sa phrase par Qwen 3 4B.
- **IA locale Qwen** : llama.cpp intégré (`flutter_app/packages/llama_flutter_android`, Android uniquement), modèle `<support>/llm/qwen3-4b-instruct.gguf`.
- **Traduction en direct** : ML Kit, sur le téléphone.
- **TalkTome Boost** (`pc_server/`) : quand le PC est joignable (Wi-Fi ou Tailscale), voix et Qwen tournent sur sa carte graphique ; sinon le téléphone fait tout.

Les modèles de voix, le dictionnaire et Qwen ne sont pas dans le dépôt : ils ont été copiés sur le téléphone Android à la main.

## Structure
```
TalkTome/
├── flutter_app/   ← l'application
├── pc_server/     ← TalkTome Boost (serveur du PC, voir son README)
├── backend/       ← ancien serveur FastAPI Google Cloud TTS (obsolète, plus utilisé)
└── claude.md
```

## Identifiant de l'app
`com.hugocodings.talktome` (Android et iOS ; définitif une fois publié). L'ancienne app `com.example.speechify` est une app différente pour Android : ses données se recopient dans la nouvelle avec `run-as` (les deux sont des builds debug). Une app intermédiaire `com.hugo.talktome` (installée par erreur le 2026-11-23) est à désinstaller.

## Compiler et installer sur le téléphone Android (PowerShell)

```powershell
cd "c:\Users\Hdasi\Desktop\PROJETS VISUAL CODE\TalkTome\flutter_app"
$env:PATH += ";C:\Users\Hdasi\Desktop\PROJETS CLAUDE\SPEECHIFY HUGO\flutter_windows_3.41.5-stable\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools"
flutter build apk --debug
adb devices
adb -s <appareil> install -r build\app\outputs\flutter-apk\app-debug.apk
```
(Le SDK Flutter est encore rangé dans l'ancien dossier `PROJETS CLAUDE\SPEECHIFY HUGO` sur le PC.)

⚠️ Ne jamais utiliser `flutter install` pour mettre à jour l'app : ça désinstalle l'app avant de la réinstaller et efface toutes les données locales. Toujours `adb install -r`, qui les préserve.

Débogage sans fil : `adb pair <ip>:<port d'appairage>` (une fois), puis `adb connect <ip>:<port>` ; l'appareil s'appelle alors `<ip>:<port>`.

## Dépôt Git / GitHub
- Dépôt : `https://github.com/hugocodings-design/TalkTome`.
- **Une seule branche principale : `master`** = la version Android avec le design Tomy (le livre à cape qui parle : thème `lib/theme/talktome_theme.dart`, `lib/widgets/tomy.dart`). Tout le travail part de `master` et y revient ; pas d'autres branches durables. Avant de compiler pour le téléphone : être sur `master` à jour (`git pull`).
- La version iPhone vit sur sa propre branche `ios` (voir le `claude.md` de cette branche) ; pour lui apporter une nouveauté Android : `git checkout ios && git merge master`. Ne jamais fusionner `ios` dans `master`.

## Voix (phase de développement)
Chaque voix s'affiche « <moteur> <nom> ♀/♂ », dans une section « <langue> · <moteur> · téléphone | ordinateur requis » (`lib/data/voice_characters.dart`). Catalogue : `lib/services/sherpa_tts_service.dart` ; modèles téléchargeables depuis Profil → Voix IA.

| Moteur | Où | Langues | Voix |
|---|---|---|---|
| Kokoro (fp32) | téléphone | EN 3F+3M, FR 1F, PT-BR 1F+2M | natives uniquement |
| Supertonic 3 (int8) | téléphone | FR, EN, PT : 3F+3M chacune | F1–F3 = identifiants 0–2, M1–M3 = 5–7 ; langue passée par `extra: {'lang': …}` |
| Pocket TTS (int8) | téléphone | EN 3F+3M | Alba, Vera, Jane, George, Ewan, Callum : voix imitées d'extraits Kyutai (`<modèle>/voices/*.wav`, téléchargés avec le modèle ou à la première phrase), choisis pour leur constance d'une phrase à l'autre. Texte nettoyé avant synthèse (`pocketCleanText` : pas de guillemets typographiques, …, parenthèses dans son vocabulaire) |
| Piper | téléphone | FR, PT | anciennes voix (Miro FR/PT, Dii et Tom interdits en usage commercial) |
| Qwen3-TTS | **ordinateur uniquement** (TalkTome Boost) | FR, EN, PT-PT : 3F+3M chacune | décrites dans `pc_server/qwen_voices.json` (mêmes identifiants), créées par `install_qwen_tts.ps1` |

Le serveur du PC ne fait tourner que Kokoro, Piper et Qwen3 ; Supertonic et Pocket restent toujours sur le téléphone.

⚠️ Avant publication : ajouter un écran de crédits. Les extraits de voix Pocket sont sous CC-BY-4.0 (corpus VCTK, Université d'Édimbourg ; Alba MacKenna via Kyutai) et doivent être crédités.

## APK sur GitHub (téléchargement de l'app)
- Workflow `.github/workflows/android-apk.yml` : à chaque changement sur `master`, GitHub construit l'APK (debug, arm64) et le publie dans la version **latest** : https://github.com/hugocodings-design/TalkTome/releases/latest (fichier `TalkTome.apk`). Dépôt privé : il faut être connecté à GitHub pour télécharger.
- Signature : la **clé de débogage du PC de Hugo** (`%USERPROFILE%\.android\debug.keystore`), pour que l'APK téléchargé mette à jour l'app installée sans perdre ses données. Elle est fournie à GitHub par le secret de dépôt `ANDROID_DEBUG_KEYSTORE_BASE64` = le fichier encodé en base64 (Settings → Secrets and variables → Actions). Sans ce secret, la construction sur `master` s'arrête volontairement.
- Pour la mettre en place (une fois, depuis le PC) : encoder le fichier en base64 (PowerShell : `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))`) et l'enregistrer comme secret, par exemple avec `gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 --repo hugocodings-design/TalkTome`, puis relancer le workflow (onglet Actions → Android APK → Run workflow).
- Une clé de débogage ne convient pas au Play Store : une vraie clé de publication sera nécessaire pour la mise en ligne.
