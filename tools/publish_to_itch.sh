#!/bin/bash
set -e
GAME_ID=

cd exports
butler push lovejs pumkinhead/$GAME_ID:html5 --if-changed
butler push win-x64 pumkinhead/$GAME_ID:win-x64 --if-changed
butler push monoware.love pumkinhead/$GAME_ID:love --if-changed
cd ..