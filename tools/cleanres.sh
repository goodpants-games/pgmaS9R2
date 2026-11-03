#!/bin/bash
# removes files listed in app/res/.gitignore
cd app/res
rm -f $(cat .gitignore | awk '{$1=$1;print}')