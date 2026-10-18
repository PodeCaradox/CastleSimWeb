# Castle Sim Web

Plain static server for the wasm build. No Angular, no dependencies.

    npm start        # http://localhost:8080 (PORT overrides)

`index.html` loads `wasm/castle_sim.js` and the game data from `assets/`. Both come from
`./build.sh` in the castle_sim repo, which writes them here. Commit the `wasm/` and `assets/`
folders: the server needs nothing else.

A push to `main` publishes `index.html`, `wasm/` and `assets/` to GitHub Pages (`.github/workflows/pages.yml`).
