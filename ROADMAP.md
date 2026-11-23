# TalkTome — Project Roadmap

_Last updated: 2026-08-28. Generated from git history (`54c1595` → `1f8ea46`) and current repo structure._

## What this is

An AI-powered ebook reader (Flutter app + FastAPI backend) that lets you import or scan books and listen to them read aloud with Google Cloud TTS, with synced word highlighting, annotations, in-app dictionary/translation, and reading stats.

---

## Timeline

### Phase 1 — Foundation (2026-08-14)
- Initial commit: FastAPI backend (`backend/main.py`) with `/api/voices` and `/api/synthesize`, plus the first Flutter scaffold (Home, Reader, Settings screens; Ebook/Chapter/AudioChunk models; TTS/File/Audio services).
- Fixed an event-loop blocking bug in the backend and added retry-on-quota-exceeded for the TTS API.

### Phase 1.5 — Backend hardening (2026-08-16 → 2026-08-17)
- Corrected the cloud voice catalog (removed deprecated "Journey" voices and other invalid entries).
- Added word-by-word timestamps to the synthesis response — the groundwork for word-level highlighting.

### Phase 2 — Major feature expansion (2026-08-24, checkpoint commit)
This was a large jump (~300 files) that added most of the app's current identity:
- **Voice system overhaul**: Chirp3 personas with avatar images across en-GB/en-US/es-ES/es-US/fr-CA/fr-FR/pt-BR, a local (offline) TTS fallback service, and a direct Google TTS service.
- **Book scanning pipeline**: camera capture → crop → OCR → "scan to book" conversion, with its own screens (`scan/camera_capture_screen`, `scan/crop_screen`, `scan_review_screen`) and services (`ocr_service`, `image_processing_service`, `scan_to_book_service`), including a test suite.
- **Background audio**: `talktome_audio_handler` (large, ~830 lines) for lock-screen/notification playback controls.
- **App navigation redesign**: `main_screen` (bottom nav), `recent_screen`, `profile_screen`, folders (`folder` model) for organizing the library, and a persistent `mini_player` widget.
- **Reading stats**: `stats_service`.

### Phase 3 — Annotations & highlighting (2026-08-24)
- Text highlighting synced to playback + a dedicated Annotations tab/screen (`annotation` model, `annotations_screen`), replacing the old standalone Settings screen content (folded into Profile).

### Phase 4 — Dictionary & translation (2026-08-27, most recent)
- In-app dictionary powered by Gemini (`dictionary_service`, `dictionary_sheet`).
- Live and manual translation via Google Translate (`translation_service`, `translation_sheet`).
- Large expansion of `reader_screen` (+1030 lines) to wire these into the reading experience.

### Phase 5 — Reader polish & rebrand (2026-11)
- Text-only mode (eye icon) keeps the progress bar visible; adjustable top/bottom text margins (Profile → Texte) apply in book mode and text-only mode.
- Rebranded to **TalkTome** (PC acceleration: **TalkTome Boost**) with a new Android package ID, `com.hugocodings.talktome`, ahead of a Google Play internal test. Mascot (Tomy) and "Mystic night" theme defined; implementation is next.

---

## Current feature set (as of `1f8ea46`)

- Import ebooks (PDF/EPUB) or **scan physical books** via camera + OCR
- Organize library into folders, with a Recent list and Home overview
- TTS playback via Google Cloud (Chirp3 + Neural2 voices, 380+ voices, per-voice avatars) or local/offline voices
- Background/lock-screen playback controls
- Word-by-word highlighting synced to audio
- Text annotations/highlights with a dedicated tab
- In-reader dictionary lookups (Gemini) and translation (Google Translate)
- Reading stats tracking
- Profile screen, mini-player, Material 3 UI

## Architecture snapshot

- **Backend** (`backend/main.py`, FastAPI): `/api/health`, `/api/voices`, `/api/synthesize` (now with word timestamps + retry/backoff on quota errors). Run locally via `uvicorn`; no deployment yet (Cloud Run was the original plan, not yet done).
- **App** (`flutter_app/`): Hive for local storage, `just_audio`/`audio_service`-based playback, Dart `pdf`/`epub` extraction, plus new OCR/camera/scan stack.
- Secrets handled via `secrets.example.dart` (real `secrets.dart` gitignored).

## Open items / not yet done

- Original Phase 1 checklist in `PHASE_1_SETUP.md` was never formally checked off (work proceeded past it directly).
- No backend deployment (Cloud Run/hosting) — still local-only.
- Test coverage is minimal (one test file: `scan_to_book_service_test.dart`).
- No CI pipeline.
- Primary testing has been on a single physical Android device; iOS/desktop platform folders exist but are unverified.
