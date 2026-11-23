# Installe TalkTome Boost pour qu'il démarre tout seul avec Windows.
#  - copie le serveur dans %LOCALAPPDATA%\TalkTomeBoost
#  - crée un lanceur silencieux (sans fenêtre)
#  - ajoute un raccourci dans le dossier Démarrage de l'utilisateur
# Désinstaller : supprimer le raccourci « TalkTome Boost » du dossier
# shell:startup (et le dossier %LOCALAPPDATA%\TalkTomeBoost si voulu).

$base = Join-Path $env:LOCALAPPDATA 'TalkTomeBoost'
$startup = [Environment]::GetFolderPath('Startup')

# Ancienne installation (nom « SpeechifyBoost ») : on arrête le serveur, on
# déplace le dossier tel quel (environnement Python, modèles, code
# d'appairage : rien à retélécharger) et on retire l'ancien raccourci.
$old = Join-Path $env:LOCALAPPDATA 'SpeechifyBoost'
if ((Test-Path $old) -and -not (Test-Path $base)) {
    Get-CimInstance Win32_Process | Where-Object {
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($old, 'OrdinalIgnoreCase')) -or
        ($_.CommandLine -and $_.CommandLine -like "*$old*")
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    Move-Item $old $base
    Remove-Item (Join-Path $base 'speechify_boost.py') -ErrorAction SilentlyContinue
    Write-Output "Ancienne installation déplacée vers $base"
}
Remove-Item (Join-Path $startup 'Speechify Boost.lnk') -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force $base | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'talktome_boost.py') $base -Force
Copy-Item (Join-Path $PSScriptRoot 'boost_supervisor.py') $base -Force

# python.exe (pas pythonw) : c'est lui qu'autorise le pare-feu Windows ; la
# fenêtre reste cachée grâce au style 0 de sh.Run.
$pyw = Join-Path $base 'venv\Scripts\python.exe'
# Le raccourci lance le superviseur, qui démarre le serveur et le relance
# s'il s'arrête.
$script = Join-Path $base 'boost_supervisor.py'
$vbs = Join-Path $base 'start_boost.vbs'
@"
Set sh = CreateObject("WScript.Shell")
sh.Run """$pyw"" ""$script""", 0, False
"@ | Out-File -Encoding ascii $vbs

$lnk = Join-Path $startup 'TalkTome Boost.lnk'
$shell = New-Object -ComObject WScript.Shell
$s = $shell.CreateShortcut($lnk)
$s.TargetPath = 'wscript.exe'
$s.Arguments = "`"$vbs`""
$s.WorkingDirectory = $base
$s.Description = 'TalkTome Boost - acceleration de l''app par l''ordinateur'
$s.Save()

Write-Output "Installé. Lanceur : $vbs"
Write-Output "Démarrage automatique : $lnk"

# Pare-feu : autorise Boost (TCP pour les voix et l'IA, UDP pour que le
# téléphone retrouve l'ordinateur), quel que soit le type de réseau choisi
# dans Windows, mais seulement depuis le réseau local et Tailscale.
$port = 47815
try {
    $cfg = Get-Content (Join-Path $base 'config.json') -Raw | ConvertFrom-Json
    if ($cfg.port) { $port = [int]$cfg.port }
} catch {}
try {
    Get-NetFirewallRule -DisplayName 'TalkTome Boost*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    foreach ($proto in 'TCP', 'UDP') {
        New-NetFirewallRule -DisplayName "TalkTome Boost ($proto)" -Direction Inbound -Action Allow `
            -Protocol $proto -LocalPort $port -Profile Any `
            -RemoteAddress LocalSubnet, '100.64.0.0/10' | Out-Null
    }
    # Une règle « Bloquer » créée par un ancien refus de la fenêtre du
    # pare-feu l'emporterait sur l'autorisation : on la retire (Python de
    # Boost uniquement).
    Get-NetFirewallApplicationFilter -Program $pyw -ErrorAction SilentlyContinue |
        Get-NetFirewallRule | Where-Object { $_.Action -eq 'Block' } | Remove-NetFirewallRule
    Write-Output "Pare-feu : port $port autorisé (réseau local et Tailscale)."
} catch {
    Write-Output "Pare-feu non modifié (lancez PowerShell en administrateur) : $_"
}

# Remplace l'instance en cours (ancienne version comprise), puis démarre.
Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and ($_.CommandLine -like '*talktome_boost.py*' -or $_.CommandLine -like '*boost_supervisor.py*')
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
Start-Process wscript.exe -ArgumentList "`"$vbs`"" -WorkingDirectory $base
Write-Output "TalkTome Boost démarré (relancé automatiquement s'il s'arrête)."
