set -e
python3 tools/assetexport.py
love app --debug "$@"
