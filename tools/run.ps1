$ErrorActionPreference = 'Stop'

$env:TILED = "C:\Program Files\Tiled\tiled.exe"

python tools\assetexport.py
if ($LASTEXITCODE -ne 0) {
    exit
}

$LOVEC_L52 = if ($env:LOVEC_L52) { $env:LOVEC_L52 } else { "love\lovec_l52.exe" }
& $LOVEC_L52 app --debug $args