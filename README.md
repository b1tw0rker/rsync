# Rsync Mirror Script
This smart little script creates a copy to a mirrorserver out of the box.

## WARNING:
THIS SCRIPT COMES WITH ABSOLUTE NO WARRANTY,
THIS SCRIPT IS ABSOLUTE BETA STUFF. DO NOT USE IT ON PRODUCTION SYSTEMS

(C) 2021 by Dipl. Wirt.-Ing. Nick Herrmann

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

Change the config files: exclude.cf, files.cf, folder.cf to your personal needs

```bash
exclude.cf -> insert files ord folders which should NOT be copied.
```

```bash
files.cf -> insert files which should be copied.
```


```bash
folder.cf -> insert folders which should be copied.
```

That's it folks! Happy mirroring ;-)

## License
[APACHE](https://www.apache.org/licenses/LICENSE-2.0)