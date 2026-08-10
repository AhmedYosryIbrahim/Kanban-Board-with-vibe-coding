# Scripts

Start and stop the app in Docker, from the repo root, on Mac, Linux, and
Windows.

Status: not yet implemented. Part 2 of `docs/PLAN.md` creates these.

## Files

```
scripts/
  start.sh     Mac and Linux
  stop.sh      Mac and Linux
  start.bat    Windows
  stop.bat     Windows
```

The `.sh` files must be committed with the executable bit set
(`git update-index --chmod=+x`).

## What start does

1. Fail with a clear message if `docker` is not on PATH or the daemon is down.
2. Fail with a clear message if `.env` is missing at the repo root.
3. `docker build -t kanban-app .`
4. `docker run -d --name kanban-app -p 3000:3000 --env-file .env -v kanban-data:/app/data kanban-app`
5. Print `http://localhost:3000`.

The named volume `kanban-data` is what makes the SQLite database survive a
container rebuild. Without it, stopping the app wipes the board.

## What stop does

`docker stop kanban-app` then `docker rm kanban-app`. Both tolerate the
container not existing - stopping an already-stopped app is not an error. The
`kanban-data` volume is left alone; stop must never delete user data.

## Conventions

- Scripts are run from the repo root and resolve paths relative to their own
  location, so they work from any working directory.
- `set -e` in the shell scripts.
- Container name, image name, and port are set once as variables at the top of
  each script.
- Plain text output, no colors, no emojis, no ASCII art.
- Keep them short. These are convenience wrappers around two docker commands,
  not a deployment tool.
