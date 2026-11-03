$ErrorActionPreference = 'Stop'

$env:TILED = "C:\Program Files\Tiled\tiled.exe"

python tools\assetexport.py
if ($LASTEXITCODE -ne 0) {
    exit
}
love\lovec_l52.exe app --debug $args
