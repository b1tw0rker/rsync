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

**Umbenennung Variablen (`copyjob.sh`)**
- `host` → `target` — beschreibt den Backup-Server (in `config.cf` und `copyjob.sh`)
- `target` → `remotepath` — beschreibt den Zielpfad auf dem Server
- `local` → `sourcepath` — beschreibt den lokalen Quellpfad

**Robustheit (`copyjob.sh`)**
- `set -u` hinzugefügt — Skript bricht bei nicht-initialisierten Variablen ab
- `mkdir` zu `mkdir -p "$logpath"` — nutzt Config-Variable, erstellt übergeordnete Verzeichnisse
- `$target` korrekt in Anführungszeichen gesetzt
- `exclude=""` explizit initialisiert
- SSH-Verbindungstest vor Ausführung — bricht sauber ab wenn Server nicht erreichbar
- Log-Rotation: Logs älter als 30 Tage werden automatisch gelöscht
- rsync Exit-Code wird geprüft und bei Fehler ins Log geschrieben

**README.md**
- Shields.io Badges hinzugefügt (Version, Last Commit, Lizenz)
- Lizenz von APACHE auf MIT geändert

## License
[MIT](https://opensource.org/licenses/MIT)