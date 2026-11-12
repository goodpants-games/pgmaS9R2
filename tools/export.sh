#!/bin/bash
set -e

PROJECT_ROOT=$PWD
GAME_NAME=murder-xquid
GAME_TITLE="Murder Xquid"

WIN64_BUILD_NAME=love-11.5-win64

# create game LOVE
echo "== LOVE PACKAGE =="
mkdir -p exports
cd app
cp ../CREDITS.txt ../LICENSE .
zip -FSr ../exports/${GAME_NAME}.love res CREDITS.txt LICENSE `find . -iname '*.lua' -not -path './res/*'`
rm CREDITS.txt LICENSE
cd $PROJECT_ROOT

# create win build
build_win64() {
    echo "== WIN64 EXPORT =="

    rm -rf exports/win-x64
    LOVE_WIN64_ZIP=$(mktemp) # does this need to have a .zip suffix?
    curl -L "https://github.com/love2d/love/releases/download/11.5/${WIN64_BUILD_NAME}.zip" > $LOVE_WIN64_ZIP
    unzip $LOVE_WIN64_ZIP -d exports/
    rm $LOVE_WIN64_ZIP
    mv exports/${WIN64_BUILD_NAME} exports/win-x64

    cd exports/win-x64
    rm lovec.exe changes.txt readme.txt
    mv license.txt lovelicense.txt
    cp $PROJECT_ROOT/LICENSE $PROJECT_ROOT/CREDITS.txt .
    cat love.exe ../${GAME_NAME}.love > ${GAME_NAME}.exe
    rm love.exe

    # stupid thing to disable some stupid al processing that makes the audio sound bad
    echo "stereo-mode = speakers" >> alsoft.ini

    cd $PROJECT_ROOT
}

# create web build
build_html5() {
    echo "== HTML5 EXPORT =="
    love.js -t "$GAME_TITLE" -c exports/${GAME_NAME}.love exports/lovejs
    cp -f tools/lovejs_index.html exports/lovejs/index.html
    cp -f tools/loading.png exports/lovejs/loading.png
}






if [[ "$*" == *"win64"* ]]; then
    build_win64
fi

build_html5