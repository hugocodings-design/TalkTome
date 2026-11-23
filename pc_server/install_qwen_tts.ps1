# Installe les voix Qwen3-TTS de TalkTome Boost (ordinateur uniquement).
#  - environnement Python séparé : %LOCALAPPDATA%\TalkTomeBoost\venv-qwen
#  - PyTorch pour carte NVIDIA (CUDA 12.6), le paquet qwen-tts
#  - télécharge les modèles (~8 Go) et crée les 18 voix (une fois, ~10-20 min)
#  - redémarre TalkTome Boost pour qu'il prenne les voix en charge
# À lancer APRÈS install_boost.ps1. Peut être relancé sans risque : ce qui
# existe déjà est gardé (voix comprises).

$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'TalkTomeBoost'
if (-not (Test-Path (Join-Path $base 'talktome_boost.py'))) {
    throw "TalkTome Boost n'est pas installé : lancez d'abord install_boost.ps1"
}

# Python : 3.12 de préférence (recommandé par Qwen), sinon celui du serveur
# Boost (lu dans venv\pyvenv.cfg).
$py = $null
try { & py -3.12 -c "import sys" 2>$null; if ($LASTEXITCODE -eq 0) { $py = @('py', '-3.12') } } catch {}
if (-not $py) {
    $cfgFile = Join-Path $base 'venv\pyvenv.cfg'
    $home_ = (Get-Content $cfgFile | Where-Object { $_ -match '^home\s*=' }) -replace '^home\s*=\s*', ''
    $py = @((Join-Path $home_.Trim() 'python.exe'))
}
Write-Output "Python utilisé : $($py -join ' ')"

$venv = Join-Path $base 'venv-qwen'
$vpy = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $vpy)) {
    if ($py.Count -gt 1) { & $py[0] $py[1] -m venv $venv } else { & $py[0] -m venv $venv }
}
& $vpy -m pip install --upgrade pip
# PyTorch CUDA 12.6 : compatible avec la RTX 2080 Super (architecture Turing).
& $vpy -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu126
& $vpy -m pip install qwen-tts fastapi uvicorn soundfile

Copy-Item (Join-Path $PSScriptRoot 'qwen_tts_worker.py') $base -Force
Copy-Item (Join-Path $PSScriptRoot 'qwen_voices.json') $base -Force
Copy-Item (Join-Path $PSScriptRoot 'tempo.py') $base -Force

& $vpy -c "import torch; print('Carte graphique :', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'AUCUNE (processeur, très lent)')"

Write-Output "Téléchargement des modèles et création des voix (long la première fois)..."
& $vpy (Join-Path $base 'qwen_tts_worker.py') --prepare
if ($LASTEXITCODE -ne 0) { throw "La préparation de Qwen3-TTS a échoué : voir $base\qwen_tts.log" }

# Redémarre TalkTome Boost (il lance Qwen3-TTS au démarrage).
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and ($_.CommandLine -like '*talktome_boost.py*' -or $_.CommandLine -like '*qwen_tts_worker.py*' -or $_.CommandLine -like '*boost_supervisor.py*')
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
Start-Process wscript.exe -ArgumentList "`"$(Join-Path $base 'start_boost.vbs')`"" -WorkingDirectory $base
Write-Output "Voix Qwen3-TTS installées. TalkTome Boost redémarré."
