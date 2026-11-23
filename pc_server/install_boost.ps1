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

# python.exe (pas pythonw) : c'est lui qu'autorise le pare-feu Windows ; la
# fenêtre reste cachée grâce au style 0 de sh.Run.
$pyw = Join-Path $base 'venv\Scripts\python.exe'
$script = Join-Path $base 'talktome_boost.py'
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

# Démarre tout de suite, sans attendre le prochain redémarrage.
Start-Process wscript.exe -ArgumentList "`"$vbs`"" -WorkingDirectory $base
Write-Output "TalkTome Boost démarré."
