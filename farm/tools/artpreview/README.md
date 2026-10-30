# Art preview

Renders the Parts-built models outside Roblox Studio, so a model can be checked by eye before a Studio session. It is an approximation of Roblox's lighting, not a replacement for a Studio check.

```sh
cd farm
lune run tools/artdump.luau plot tools/artpreview/scene.json   # scenes: crops, animals, buildings, factories, houses, community, plot
cd tools/artpreview
npm install                                                  # three.js; Playwright and Chromium must already be installed
node shot.js '[{"out":"plot.png","eye":"60,75,120","at":"0,0,10"}]'
```

Each shot takes `eye` and `at` (camera position and target, in studs), and optional `w`, `h` and `fov`. `scene.json`, `node_modules/` and the PNGs are not committed.

The renderer copies Roblox's part shapes: Block, Ball, Cylinder (axis along X) and Wedge (slope facing -Z, tall face at +Z).
