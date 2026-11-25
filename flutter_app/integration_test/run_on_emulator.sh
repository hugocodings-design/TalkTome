#!/usr/bin/env bash
# Lancé dans l'émulateur Android de GitHub (voir android-reading-test.yml).
set -u
cd "$(dirname "$0")/.."
PKG=com.hugocodings.talktome
OUT=../reading-test-logs
mkdir -p "$OUT"

adb logcat -c
adb logcat -v time > "$OUT/logcat.txt" 2>&1 &
LOGCAT=$!

# Dès que l'app est installée : pas d'optimisation de batterie (sinon une
# fenêtre système s'ouvre par-dessus), puis mémoire de l'app toutes les 15 s.
(
  until adb shell pm list packages | grep -q "$PKG"; do sleep 2; done
  adb shell dumpsys deviceidle whitelist +$PKG
  while true; do
    pss=$(adb shell dumpsys meminfo $PKG | awk '/TOTAL PSS:|TOTAL:/ {print $3; exit}')
    echo "$(date +%H:%M:%S) PSS_KB=${pss:-?}" >> "$OUT/memory.txt"
    sleep 15
  done
) &
WATCH=$!

flutter test integration_test/reading_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee "$OUT/test.txt"
STATUS=${PIPESTATUS[0]}

kill $WATCH $LOGCAT 2>/dev/null
echo "── Plantages dans le journal Android ──"
grep -n -E "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGABRT|Abort message|lowmemorykiller|ANR in $PKG|Process $PKG.*(died|crash)|Killing [0-9]+:$PKG" "$OUT/logcat.txt" | grep -v -E "googlequicksearchbox|com\.google\.android\.gms" | head -50 || echo "aucun"
echo "── Mémoire de l'app ──"
cat "$OUT/memory.txt" 2>/dev/null | tail -40 || true
echo "── Lignes du test ──"
grep "READING-TEST\|\[TTS\]" "$OUT/logcat.txt" | tail -60 || true
exit $STATUS
