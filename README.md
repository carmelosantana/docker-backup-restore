# ⛵️ Docker Backup and Restore Script

This script is used to backup and restore docker containers.

> Smooth sailing.

---

- [Features](#features)
- [Usage](#usage)
  - [Basic usage with interactive menu](#basic-usage-with-interactive-menu)
  - [Define backup directory](#define-backup-directory)
  - [Arguments](#arguments)
- [Funding](#funding)
- [License](#license)

## Features

- Backup and restore docker containers
- Interactive menu for easy use

## Usage

Depending on your docker setup you may need to run the script with `sudo`.

### Basic usage with interactive menu

```bash
./docker-backup-restore.sh
```

### Define backup directory

```bash
./docker-backup-restore.sh -d /path/to/backup
```

### Arguments

- `-b` Run backup. *(default: true)*
- `-d` Backup directory. *(default: ~/docker-backups)*
- `-D` Dry run. *(default: false)*
- `-k` Days to keep backups. *(default: 3)*
- `-m` Interactive menu. *(default: true)*
- `-r` Restore images. *(default: false)*
- `-p` Purge backups. *(default: false)*
- `-dd` Delete dangling images. *(default: false)*
- `-u` User to update permissions.
- `-v` Verbose output. *(default: false)*
- `-h` Display help menu

## Funding

If you find this project useful or use it in a commercial environment please consider donating today with one of the following options.

- Bitcoin `bc1qhxu9yf9g5jkazy6h4ux6c2apakfr90g2rkwu45`
- Ethereum `0x9f5D6dd018758891668BF2AC547D38515140460f`
- Patreon [`patreon.com/carmelosantana`](https://www.patreon.com/carmelosantana)

## License

The code is licensed [MIT](https://opensource.org/licenses/MIT) and the documentation is licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
