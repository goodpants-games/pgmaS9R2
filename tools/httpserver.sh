#!/bin/sh
http-server -p 8000 -c-1 \
    -H Cross-Origin-Opener-Policy:same-origin \
    -H Cross-Origin-Embedder-Policy:require-corp \
    exports/lovejs