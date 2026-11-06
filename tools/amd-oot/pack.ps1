# SPDX-FileCopyrightText: 2026 OoTTeste contributors
# SPDX-License-Identifier: GPL-3.0-or-later

# Packs a finished build into a zip that runs on a PC with nothing installed.
# Keys, firmware, saves and games must never enter the package.
param(
    [ValidateSet('generic', 'tigerlake')][string]$Target = 'generic',
    [Parameter(Mandatory)][string]$BuildDir,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$Label = 'fase5',
    [string]$QtDir = 'C:\Qt\6.8.3\msvc2022_64',
    [string]$VsDir = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bin = Join-Path $BuildDir 'bin'
if (-not (Test-Path -LiteralPath (Join-Path $bin 'lichii.exe'))) { throw "lichii.exe not found in $bin" }
if (git -C $repo status --porcelain) { throw 'The tree has uncommitted changes, so the package would not match a commit.' }
$commit = (git -C $repo rev-parse --short=10 HEAD).Trim()

$suffix = if ($Target -eq 'generic') { 'portatil' } else { 'tigerlake' }
$name = "Lichii-AMD-OoT-$Label-$suffix"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$stage = Join-Path $OutDir $name
$zip = "$stage.zip"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Force $stage | Out-Null
Get-ChildItem -LiteralPath $bin -Force | Copy-Item -Destination $stage -Recurse -Force

# The Qt plugins the emulator loads, next to the executable.
$plugins = @{
    generic            = @('qtuiotouchplugin.dll')
    iconengines        = @('qsvgicon.dll')
    imageformats       = @('qgif.dll', 'qico.dll', 'qjpeg.dll', 'qsvg.dll')
    networkinformation = @('qnetworklistmanager.dll')
    platforms          = @('qwindows.dll')
    styles             = @('qmodernwindowsstyle.dll')
    tls                = @('qcertonlybackend.dll', 'qschannelbackend.dll')
}
foreach ($folder in $plugins.Keys) {
    New-Item -ItemType Directory -Force (Join-Path $stage $folder) | Out-Null
    foreach ($file in $plugins[$folder]) { Copy-Item -LiteralPath (Join-Path $QtDir "plugins\$folder\$file") (Join-Path $stage $folder) -Force }
}

# Visual C++ runtime, from Microsoft's redistributable folder.
$crt = Get-ChildItem -LiteralPath (Join-Path $VsDir 'VC\Redist\MSVC') -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_ 'msvcp140.dll') } | Select-Object -First 1
if (-not $crt) { throw "Visual C++ runtime not found under $VsDir" }
foreach ($dll in 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'msvcp140_atomic_wait.dll', 'msvcp140_codecvt_ids.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'vcruntime140_threads.dll', 'concrt140.dll') {
    Copy-Item -LiteralPath (Join-Path $crt $dll) $stage -Force
}

# Portable mode: the user folder next to the executable, starting with the tested settings.
New-Item -ItemType Directory -Force (Join-Path $stage 'user\config') | Out-Null
@'
[Renderer]
gpu_accuracy\default=false
gpu_accuracy=0
async_presentation\default=false
async_presentation=true
use_asynchronous_shaders\default=false
use_asynchronous_shaders=true

[System]
use_docked_mode\default=false
use_docked_mode=1
'@ | Set-Content -Encoding ascii (Join-Path $stage 'user\config\qt-config.ini')
@'
Esta pasta guarda os dados do emulador: configuracoes, saves, firmware e keys.
Ela fica aqui para o emulador nao usar a pasta do Windows.
Coloque suas keys em user\keys. O firmware e instalado pelo menu do proprio emulador.
'@ | Set-Content -Encoding ascii (Join-Path $stage 'user\LEIA-ME-user.txt')

$cpu = if ($Target -eq 'generic') { 'Processador com SSE4.1.' } else { 'Processador Intel Tiger Lake. Em outros, o programa pode fechar ao abrir: use a versao portatil.' }
$utf8 = New-Object Text.UTF8Encoding($true)
$readme = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'LEIA-ME-portatil.txt'), $utf8)
$readme = $readme.Replace('{{LABEL}}', $Label).Replace('{{TARGET}}', $Target).Replace('{{CPU}}', $cpu).Replace('{{COMMIT}}', $commit)
[IO.File]::WriteAllText((Join-Path $stage 'LEIA-ME.txt'), $readme, $utf8)
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE.txt') $stage -Force
Copy-Item -LiteralPath (Join-Path $repo 'LICENSES\LGPL-3.0-or-later.txt') (Join-Path $stage 'LICENSE-Qt-LGPL-3.0.txt') -Force

$bad = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Extension -in '.keys', '.nca', '.nup', '.xci', '.nsp', '.sav', '.log' -or $_.FullName -match '\\(nand|sdmc|keys|cache|log)\\' }
if ($bad) { throw ("Personal or game files in the package: " + (($bad | ForEach-Object Name) -join ', ')) }

# Launch test on a throwaway copy, so the package stays clean.
if (Get-Process lichii, eglantine, eden-cli -ErrorAction SilentlyContinue) {
    'Teste de abertura PULADO: ja existe um emulador aberto.'
} else {
    $test = Join-Path $OutDir "teste-$suffix"
    if (Test-Path -LiteralPath $test) { Remove-Item -LiteralPath $test -Recurse -Force -Confirm:$false }
    Copy-Item -LiteralPath $stage $test -Recurse -Force
    Get-Item Env:EDEN_* -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item "Env:$($_.Name)" }
    $p = Start-Process -FilePath (Join-Path $test 'lichii.exe') -WorkingDirectory $test -WindowStyle Minimized -PassThru
    Start-Sleep 15
    $p.Refresh()
    if ($p.HasExited) {
        throw ("Launch test failed: the process exited with code " + $p.ExitCode)
    }
    "Teste de abertura: responding=" + $p.Responding + ", titulo='" + $p.MainWindowTitle + "'"
    if ($p.MainWindowTitle -notlike "*$commit*") { "AVISO: o titulo nao contem o commit $commit; a build pode nao ser deste commit." }
    $p.Modules | Where-Object { $_.ModuleName -match '^(msvcp140|vcruntime140|qt6core)' } | ForEach-Object { "  " + $_.ModuleName + " -> " + $(if ($_.FileName -like "$test*") { 'da pasta do pacote' } else { $_.FileName }) }
    Stop-Process -Id $p.Id -Force -Confirm:$false
    $p.WaitForExit(10000) | Out-Null
    Start-Sleep 1
    Select-String -LiteralPath (Join-Path $test 'user\config\qt-config.ini') -Pattern '^(gpu_accuracy|use_docked_mode|async_presentation|use_asynchronous_shaders)=' | ForEach-Object { "  " + $_.Line }
    Remove-Item -LiteralPath $test -Recurse -Force -Confirm:$false
}

if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force -Confirm:$false }
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
"Zip: $zip"
"Tamanho: " + (Get-Item -LiteralPath $zip).Length
"SHA-256: " + (Get-FileHash -LiteralPath $zip).Hash
"Commit: $commit"
