#!/bin/bash

###############################################################################
# Magic Mirror Backup Script
# Sichert das gesamte /home/pi Verzeichnis regelmäßig auf die NAS
# (ausgenommen img_cache Verzeichnisse)
###############################################################################

# Konfiguration
BACKUP_SOURCE="${HOME}"  # Sichere alles unter /home/pi
BACKUP_DEST="/mnt/dsm/backup/magicmirror"
BACKUP_RETENTION_DAYS=30  # Anzahl der Tage, die Backups aufbewahrt werden
LOG_FILE="${HOME}/.magicmirror_backup.log"
DATE_FORMAT=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="magicmirror_backup_${DATE_FORMAT}"

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Fehlerbehandlung
error_exit() {
    log "${RED}FEHLER: $1${NC}"
    exit 1
}

# Prüfe ob Backup-Quelle existiert
if [ ! -d "${BACKUP_SOURCE}" ]; then
    error_exit "Backup-Quelle nicht gefunden: ${BACKUP_SOURCE}"
fi

# Prüfe ob Backup-Ziel existiert und beschreibbar ist
if [ ! -d "${BACKUP_DEST}" ]; then
    log "${YELLOW}Warnung: Backup-Verzeichnis existiert nicht, wird erstellt...${NC}"
    mkdir -p "${BACKUP_DEST}" || error_exit "Konnte Backup-Verzeichnis nicht erstellen: ${BACKUP_DEST}"
fi

if [ ! -w "${BACKUP_DEST}" ]; then
    error_exit "Keine Schreibrechte auf Backup-Verzeichnis: ${BACKUP_DEST}"
fi

log "${GREEN}Starte Backup von ${BACKUP_SOURCE}...${NC}"
log "Quelle: ${BACKUP_SOURCE}"
log "Ziel: ${BACKUP_DEST}/${BACKUP_NAME}"

# Erstelle temporäres Verzeichnis für Backup
TEMP_BACKUP_DIR="${BACKUP_DEST}/${BACKUP_NAME}"
mkdir -p "${TEMP_BACKUP_DIR}" || error_exit "Konnte temporäres Backup-Verzeichnis nicht erstellen"

# Backup mit rsync (effizienter als tar für inkrementelle Backups)
# Exclude-Liste: Dateien/Verzeichnisse die nicht gesichert werden müssen
# WICHTIG: Patterns sind relativ zum BACKUP_SOURCE (/home/pi)
EXCLUDE_LIST=(
    # img_cache überall ausschließen (mit verschiedenen Pfad-Varianten)
    "--exclude=**/img_cache"
    "--exclude=**/img_cache/**"
    "--exclude=MagicMirror/modules/MMM-SynPhotoSlideshow/img_cache"
    "--exclude=MagicMirror/modules/MMM-SynPhotoSlideshow/img_cache/**"

    # Standard-Ausschlüsse
    "--exclude=**/node_modules"
    "--exclude=**/.image-cache"
    "--exclude=**/coverage"
    "--exclude=**/output"
    "--exclude=**/.git"
    "--exclude=**/.eslintcache"
    "--exclude=**/*.log"
    "--exclude=**/.env"
    "--exclude=**/filesShownTracker.txt"
    "--exclude=**/junit.xml"
    "--exclude=**/*.js.map"
    "--exclude=**/.idea"

    # System-Verzeichnisse die nicht gesichert werden müssen
    "--exclude=.cache"
    "--exclude=.local/share/Trash"
    "--exclude=.thumbnails"
    "--exclude=.npm"
    "--exclude=.node-gyp"
)

# Führe Backup durch
# WICHTIG: Trailing Slash bei BACKUP_SOURCE sorgt dafür, dass der Inhalt
# (nicht das Verzeichnis selbst) gesichert wird
log "Sichere Dateien..."
rsync -av --delete \
    "${EXCLUDE_LIST[@]}" \
    "${BACKUP_SOURCE}/" \
    "${TEMP_BACKUP_DIR}/" \
    >> "${LOG_FILE}" 2>&1

if [ $? -eq 0 ]; then
    log "${GREEN}Backup erfolgreich abgeschlossen${NC}"

    # Erstelle zusätzlich ein komprimiertes Archiv
    log "Erstelle komprimiertes Archiv..."
    cd "${BACKUP_DEST}" || error_exit "Konnte nicht in Backup-Verzeichnis wechseln"
    tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}" 2>> "${LOG_FILE}"

    if [ $? -eq 0 ]; then
        log "${GREEN}Archiv erstellt: ${BACKUP_NAME}.tar.gz${NC}"
        # Lösche unkomprimiertes Verzeichnis um Platz zu sparen
        rm -rf "${TEMP_BACKUP_DIR}"
        log "Unkomprimiertes Verzeichnis entfernt (nur Archiv behalten)"
    else
        log "${YELLOW}Warnung: Archiv konnte nicht erstellt werden, behalte unkomprimiertes Backup${NC}"
    fi

    # Berechne Größe des Backups
    BACKUP_SIZE=$(du -sh "${BACKUP_DEST}/${BACKUP_NAME}.tar.gz" 2>/dev/null | cut -f1 || echo "unbekannt")
    log "Backup-Größe: ${BACKUP_SIZE}"

else
    error_exit "Backup fehlgeschlagen! Siehe Log: ${LOG_FILE}"
fi

# Alte Backups löschen (Retention Policy)
log "Bereinige alte Backups (älter als ${BACKUP_RETENTION_DAYS} Tage)..."
find "${BACKUP_DEST}" -name "magicmirror_backup_*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS} -delete
DELETED_COUNT=$(find "${BACKUP_DEST}" -name "magicmirror_backup_*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS} 2>/dev/null | wc -l)
if [ "${DELETED_COUNT}" -gt 0 ]; then
    log "${YELLOW}${DELETED_COUNT} alte Backup(s) gelöscht${NC}"
fi

# Zeige verbleibende Backups
REMAINING_BACKUPS=$(find "${BACKUP_DEST}" -name "magicmirror_backup_*.tar.gz" -type f | wc -l)
log "${GREEN}Verbleibende Backups: ${REMAINING_BACKUPS}${NC}"

log "${GREEN}Backup-Prozess abgeschlossen!${NC}"
