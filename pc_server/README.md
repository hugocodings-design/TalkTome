# TalkTome Boost

The PC speeds up the app: AI voices and Qwen run on the RTX 2080 Super instead of the phone. If the PC can't be reached, the phone does everything itself, as before.

Everything is installed in `%LOCALAPPDATA%\TalkTomeBoost` (venv, models, llama.cpp, `config.json` holding the pairing code).

## Start automatically with Windows (one time)

```powershell
powershell -ExecutionPolicy Bypass -File "pc_server\install_boost.ps1"
```

The script also starts it right away. Windows will ask about the firewall: allow it on **private networks**.

**Already installed under the old name (`%LOCALAPPDATA%\SpeechifyBoost`)?** Run the same command: it stops the old server, moves the folder to `TalkTomeBoost` as is (Python environment, models and pairing code are kept, nothing is downloaded again) and replaces the startup shortcut. Windows asks about the firewall once more because the path changed.

## Qwen3-TTS voices (computer only, optional)

18 extra voices (3 female + 3 male in English, French and European Portuguese) that only the PC can generate. In the app they are labelled **Qwen3 …** in sections marked **« ordinateur requis »**; they don't work with the phone alone.

```powershell
powershell -ExecutionPolicy Bypass -File "pc_server\install_qwen_tts.ps1"
```

Run it after `install_boost.ps1`. It creates a separate Python environment (`%LOCALAPPDATA%\TalkTomeBoost\venv-qwen`), installs PyTorch for NVIDIA cards, downloads the models (~8 GB) and creates the 18 voices once from their descriptions in `qwen_voices.json` (10–20 minutes the first time), then restarts Boost.

- Graphics memory: the 1.7B model needs about 4–5 GB. On an 8 GB card, if voices fail while Qwen (dictionary AI) is also loaded, add `"qwen_tts_size": "0.6B"` to `config.json` and restart Boost.
- The model is released from the graphics card after 10 idle minutes (`"qwen_tts_idle_minutes"` in `config.json`).
- Logs: `qwen_tts.log` and `qwen_worker.log` in `%LOCALAPPDATA%\TalkTomeBoost`.
- To change a voice: edit its description in `qwen_voices.json`, delete `qwen_voices\<id>.wav` in `%LOCALAPPDATA%\TalkTomeBoost`, and run `install_qwen_tts.ps1` again.

## On the phone

Profile → Computer acceleration → TalkTome Boost:
- addresses: `192.168.0.18` (home Wi-Fi), plus the PC's Tailscale address `100.x.y.z`
- code: the `token` value in `%LOCALAPPDATA%\TalkTomeBoost\config.json`

## Anywhere (Tailscale)

Install Tailscale on the PC and on the phone, signed in to the same account. Then add the PC's `100.x.y.z` address to the phone's address list.

## Uninstall

Delete the "TalkTome Boost" shortcut from `shell:startup`. Optionally delete `%LOCALAPPDATA%\TalkTomeBoost` too.
