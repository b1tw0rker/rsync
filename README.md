# Rsync Mirror Script

![version](https://img.shields.io/badge/version-v1.0.2-green.svg) ![last commit](https://img.shields.io/github/last-commit/b1tw0rker/rsync.svg) ![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

This smart little script creates a copy to a mirrorserver out of the box.

## WARNING:
THIS SCRIPT COMES WITH ABSOLUTE NO WARRANTY,
THIS SCRIPT IS ABSOLUTE BETA STUFF. DO NOT USE IT ON PRODUCTION SYSTEMS

(C) 2021-2026 by Dipl. Wirt.-Ing. Nick Herrmann

This program is WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

## Installation

```bash
git clone https://github.com/b1tw0rker/rsync.git
```

Start the script with running the following command on your shell:

```bash
./copyjob.sh
```
## Configuration

### config.cf

The main configuration file. Edit these two settings before running the script:

| Variable | Description | Default |
|----------|-------------|---------|
| `target` | Hostname or IP of the backup server (SSH access required) | `XXX` |
| `active` | `true` = run rsync, `false` = dry-run (only print commands) | `true` |

> If `target` is still set to `XXX`, the script will ask for the server name on first run and save it automatically.

### Config files

Change the config files: exclude.cf, files.cf, folder.cf to your personal needs

```bash
exclude.cf  ->  files or folders that should NOT be copied (one entry per line)
files.cf    ->  files to copy (absolute paths, one per line)
folder.cf   ->  folders to copy (absolute paths with trailing /, one per line)
```

> **Note:** All paths must be absolute (starting with `/`). Folders must end with a `/`.

That's it folks! Happy mirroring ;-)

## Changelog

### v1.0.2 — 2026-05-08

**Variable Renaming (`copyjob.sh`)**
- `host` → `target` — describes the backup server (in `config.cf` and `copyjob.sh`)
- `target` → `remotepath` — describes the destination path on the server
- `local` → `sourcepath` — describes the local source path

**Robustness (`copyjob.sh`)**
- Added `set -u` — script aborts on uninitialized variables
- Changed `mkdir` to `mkdir -p "$logpath"` — uses config variable, creates parent directories
- `$target` properly quoted
- `exclude=""` explicitly initialized
- SSH connectivity check before execution — aborts cleanly if server is unreachable
- Log rotation: logs older than 30 days are automatically deleted
- rsync exit code is checked and written to log on failure

**README.md**
- Added Shields.io badges (version, last commit, license)
- Changed license from APACHE to MIT

## License
[MIT](https://opensource.org/licenses/MIT)