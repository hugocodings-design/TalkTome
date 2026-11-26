# TalkTome Boost

The PC speeds up the app: AI voices and Qwen run on the RTX 2080 Super instead of the phone. If the PC can't be reached, the phone does everything itself, as before.

Everything is installed in `%LOCALAPPDATA%\TalkTomeBoost` (venv, models, llama.cpp, `config.json` holding the pairing code).

## Start automatically with Windows (one time)

```powershell
powershell -ExecutionPolicy Bypass -File "pc_server\install_boost.ps1"
```

The script also starts it right away. Windows will ask about the firewall: allow it on **private networks**.

**Already installed under the old name (`%LOCALAPPDATA%\SpeechifyBoost`)?** Run the same command: it stops the old server, moves the folder to `TalkTomeBoost` as is (Python environment, models and pairing code are kept, nothing is downloaded again) and replaces the startup shortcut. Windows asks about the firewall once more because the path changed.

## Staying connected

- **Auto-restart:** the startup shortcut runs `boost_supervisor.py`, which starts the server and restarts it 5 seconds after any crash (`supervisor.log`).
- **The phone finds the PC by itself (Android):** if none of the saved addresses answer, the app asks the Wi-Fi network for TalkTome Boost (UDP broadcast on the Boost port) and saves the PC's new address. Handy when the router gives the PC a different address. The pairing code is still required.
- **Firewall:** `install_boost.ps1` (run as administrator) allows the Boost port for TCP and UDP from the local network and Tailscale only, whatever network type Windows picked, and removes any old "block" rule for Boost's Python.
- **Sleep:** the PC stays awake while a phone has used Boost in the last 10 minutes; otherwise Windows sleeps as usual. A sleeping or switched-off PC can't answer: the phone then uses its own voices.

## Qwen3-TTS voices (computer only, optional)

18 extra voices (3 female + 3 male in English, French and European Portuguese) that only the PC can generate. In the app they are labelled **Qwen3 …** in sections marked **« ordinateur requis »**; they don't work with the phone alone.

```powershell
powershell -ExecutionPolicy Bypass -File "pc_server\install_qwen_tts.ps1"
```

Run it after `install_boost.ps1`. It creates a separate Python environment (`%LOCALAPPDATA%\TalkTomeBoost\venv-qwen`), installs PyTorch for NVIDIA cards, downloads the models (~8 GB) and creates the 18 voices once from their descriptions in `qwen_voices.json` (10–20 minutes the first time), then restarts Boost.

- **Emotions (expressive reading):** each voice also gets one sample per emotion (happy, excited, sad, angry, scared, calm), created from the voice's description plus the emotion's. Three attempts are made per emotion and the one whose voiceprint is closest to the neutral voice is kept (`"qwen_emotion_candidates"` in `config.json`). First install takes about an hour; rerunning the installer resumes where it stopped. The same samples are fetched by the phone for the Pocket "emotions" voices (Profile → AI voices → Fetch from the computer).
- Graphics memory: the 1.7B model needs about 4–5 GB. On an 8 GB card, if voices fail while Qwen (dictionary AI) is also loaded, add `"qwen_tts_size": "0.6B"` to `config.json` and restart Boost.
- The model is released from the graphics card after 10 idle minutes (`"qwen_tts_idle_minutes"` in `config.json`).
- Logs: `qwen_tts.log` and `qwen_worker.log` in `%LOCALAPPDATA%\TalkTomeBoost`.
- To change a voice: edit its description in `qwen_voices.json`, delete `qwen_voices\<id>.wav` in `%LOCALAPPDATA%\TalkTomeBoost`, and run `install_qwen_tts.ps1` again.

## On the phone

Profile → Computer acceleration → TalkTome Boost:
- addresses: `192.168.0.18` (home Wi-Fi), plus the PC's Tailscale address `100.x.y.z`
- code: the `token` value in `%LOCALAPPDATA%\TalkTomeBoost\config.json`

## Anywhere, without Tailscale on the phone (Tailscale Funnel)

`install_boost.ps1` publishes Boost with Tailscale Funnel at `https://<pc>.<tailnet>.ts.net/talktome`
(`tailscale funnel --bg --set-path /talktome http://127.0.0.1:47815`). On the phone:
- addresses: `192.168.0.18, https://<pc>.<tailnet>.ts.net/talktome`
- code: the **`remote_key`** value in `config.json` (it also works on the home Wi-Fi)

Requests through Funnel reach Boost from 127.0.0.1: only `remote_key` (256 bits) is accepted there, never the
6-digit code, and 10 bad keys in a minute lock Funnel access for a minute. Boost ignores `X-Forwarded-For`
(`proxy_headers=False`), so a request from the Internet can't pass for a Wi-Fi one.

## Anywhere (Tailscale on the phone)

Install Tailscale on the PC and on the phone, signed in to the same account. Then add the PC's `100.x.y.z` address to the phone's address list.

## Uninstall

Delete the "TalkTome Boost" shortcut from `shell:startup`. Optionally delete `%LOCALAPPDATA%\TalkTomeBoost` too.
