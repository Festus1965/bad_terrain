# bad_terrain

This mod damages players when they stand on dangerous terrain. Anything with the surface_hot  or poison group set will cause damage every three seconds. The surface_cold group will cause damage more slowly. Players are informed in chat when they take damage from nodes. Ice and snow are automatically added to the surface_cold group.

It also provides support for traps set off by a player coming too close. A trap node must have two groups set, the "trap" group and a group specific for the trap type, including:

electricity_trap
explosive_trap (my favorite)
fire_trap
ice_trap (entombs the player)
lava_trap (set this in a low ceiling)
slippery_floor_trap


The source is available on github.

Code: LGPL2

Mod dependencies: default

Download: https://github.com/duane-r/bad_terrain/archive/master.zip
