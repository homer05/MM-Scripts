# MM-Scripts

Scripts für Magic Mirror Setup und Wartung.

## Scripts

### backup_magicmirror.sh

Backup-Script für Magic Mirror Installation. Sichert das gesamte `/home/pi` Verzeichnis regelmäßig auf die NAS (ausgenommen `img_cache` Verzeichnisse).

**Features:**
- Automatische Backup-Erstellung mit Zeitstempel
- Komprimierung zu `.tar.gz` Archiv
- Automatische Bereinigung alter Backups (30 Tage Retention)
- Detailliertes Logging
- Ausschluss von unnötigen Dateien (node_modules, .git, img_cache, etc.)

**Verwendung:**
```bash
chmod +x backup_magicmirror.sh
./backup_magicmirror.sh
```

**Konfiguration:**
- Backup-Quelle: `${HOME}` (standardmäßig `/home/pi`)
- Backup-Ziel: `/mnt/dsm/backup/magicmirror`
- Retention: 30 Tage
