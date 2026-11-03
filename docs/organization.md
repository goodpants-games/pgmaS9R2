# Libraries
- Baton (input library) 
- Concord (ECS library)
- Batteries (general-purpose library) *(required)*
- Error Explorer (more detailed crash screen)
- JProf (profiler) (MessagePack is its dependency)
- sceneman, sprite
- My own fork of Love.js for Web exports: https://github.com/pkhead/love.js/tree/lua52

# Project structure
I structure the project's files like:
```
assets/  (game assets in a format not yet readable by the game)
ignore/  (general folder for stuff i want excluded from version control)
root/  (LOVE game)
  [modules]...
  res/   (game resources)
tools/  (all the offline tooling)
  assetexport.py
  export.sh
  export.cmd  (this runs export.sh through the MSYS2 shell)
  run.ps1  (this runs assetexport and launches the project through my fork of LOVE with lua5.2)
README.md
TODO.txt
LICENSE  (GPL 3.0)
```

also the way i structure modules is that I put all modules directly in the root
folder: batteries and concord folder go in there; so does sprite.lua and
sceneman.lua. The game code is considered a module, so you'd put everything
related specifically to the game itself in a folder named "game"