# Builds Carthage for Windows: dist\Carthage (the app folder, no console window) and
# dist\Carthage-<version>-setup.exe (the installer). Used by .github/workflows/release.yml;
# also runs locally from the repo root:
#   powershell -ExecutionPolicy Bypass -File packaging\build_windows.ps1
# Needs Python 3.13 with PySide6 6.11, pillow, numpy, psutil and pyinstaller, and Inno Setup 6.
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$version = & $Python -c "from carthage.version import VERSION; print(VERSION)"
if ($LASTEXITCODE) { throw "couldn't read the version" }
Write-Host "Building Carthage $version"

& $Python -c "from PIL import Image; Image.open('carthage/assets/icons/carthage-512.png').save('packaging/carthage.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])"
if ($LASTEXITCODE) { throw "icon failed" }

& $Python -m PyInstaller packaging/carthage_main.py --name Carthage --noconsole --noconfirm --paths . `
    --icon packaging/carthage.ico `
    --add-data "carthage/qml;carthage/qml" `
    --add-data "carthage/assets;carthage/assets" `
    --hidden-import PySide6.QtQuick3D --hidden-import PySide6.QtMultimedia `
    --hidden-import PySide6.QtSvg --hidden-import PySide6.QtQuickControls2 `
    --collect-submodules carthage
if ($LASTEXITCODE) { throw "PyInstaller failed" }
Copy-Item LICENSE dist/Carthage/LICENSE.txt
Copy-Item THIRD_PARTY_NOTICES.md dist/Carthage/THIRD_PARTY_NOTICES.md

$iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
              "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw "Inno Setup 6 (ISCC.exe) not found" }
& $iscc /Qp "/DAppVersion=$version" packaging/carthage.iss
if ($LASTEXITCODE) { throw "Inno Setup failed" }
Write-Host "Done: dist\Carthage-$version-setup.exe"
