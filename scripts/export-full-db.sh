#!/bin/bash
# Script to export FULL database from main project
# Use this on your main project server to create a complete database backup
# This exports ALL tables including users, progress, achievements, etc.

set -e

CONTAINER_NAME=${CONTAINER_NAME:-infralabs_db}
DB_NAME=${DB_NAME:-infralabs}
DB_USER=${DB_USER:-infralabs_user}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Exporting FULL database from main project...${NC}"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Container '${CONTAINER_NAME}' is not running!${NC}"
    echo "   Please start the database container first:"
    echo "   docker-compose up -d db"
    exit 1
fi

# Create backup directory
BACKUP_DIR="./backups"
mkdir -p "${BACKUP_DIR}"

# Generate filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DUMP_FILE="${BACKUP_DIR}/infralabs_full_db_${TIMESTAMP}.sql"

echo -e "${BLUE}📥 Creating full database dump...${NC}"
echo "   Container: ${CONTAINER_NAME}"
echo "   Database:  ${DB_NAME}"
echo "   User:      ${DB_USER}"
echo "   Output:    ${DUMP_FILE}"
echo ""

# Create full database dump (schema + data)
echo -e "${YELLOW}⚠️  This will export ALL data including:${NC}"
echo "   • Users and authentication data"
echo "   • Courses, modules, lessons, exercises"
echo "   • User progress and achievements"
echo "   • Sandbox sessions"
echo "   • All other application data"
echo ""

read -p "Continue with full backup? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "Export cancelled."
    exit 0
fi

echo ""
echo "🔄 Creating database dump (this may take a while)..."
echo ""

# Create full dump with schema and data
# Using --clean to drop objects before recreating
# Using --if-exists to avoid errors if objects don't exist on restore
docker exec ${CONTAINER_NAME} pg_dump \
    -U ${DB_USER} \
    -d ${DB_NAME} \
    --clean \
    --if-exists \
    --create \
    --format=plain \
    --no-owner \
    --no-privileges \
    > "${DUMP_FILE}" 2>&1

if [ $? -eq 0 ] && [ -s "${DUMP_FILE}" ]; then
    FILE_SIZE=$(du -h "${DUMP_FILE}" | cut -f1)
    LINE_COUNT=$(wc -l < "${DUMP_FILE}" | tr -d ' ')
    
    echo ""
    echo -e "${GREEN}✅ Full database exported successfully!${NC}"
    echo "   File:      ${DUMP_FILE}"
    echo "   Size:      ${FILE_SIZE}"
    echo "   Lines:     ${LINE_COUNT}"
    echo ""
    echo "📋 Database contents:"
    
    # Count tables in dump
    TABLE_COUNT=$(grep -c "^CREATE TABLE" "${DUMP_FILE}" 2>/dev/null || echo "0")
    INDEX_COUNT=$(grep -c "^CREATE INDEX" "${DUMP_FILE}" 2>/dev/null || echo "0")
    SEQUENCE_COUNT=$(grep -c "^CREATE SEQUENCE" "${DUMP_FILE}" 2>/dev/null || echo "0")
    
    echo "   Tables:    ${TABLE_COUNT}"
    echo "   Indexes:   ${INDEX_COUNT}"
    echo "   Sequences: ${SEQUENCE_COUNT}"
    echo ""
    
    # List main tables
    echo "   Main tables found:"
    grep "^CREATE TABLE" "${DUMP_FILE}" | sed 's/CREATE TABLE public\.//' | sed 's/ (.*//' | head -20 | while read table; do
        echo "     • ${table}"
    done
    
    if [ "${TABLE_COUNT}" -gt 20 ]; then
        echo "     ... and $((TABLE_COUNT - 20)) more"
    fi
    
    echo ""
    echo -e "${GREEN}📦 To restore on new server:${NC}"
    echo "   1. Copy ${DUMP_FILE} to infralabs-deploy directory"
    echo "   2. Run: ./scripts/import-full-db.sh ${DUMP_FILE}"
    echo ""
else
    echo ""
    echo -e "${RED}❌ Failed to export database!${NC}"
    echo "   Check the error messages above"
    if [ -f "${DUMP_FILE}" ]; then
        echo "   Last 20 lines of output:"
        tail -20 "${DUMP_FILE}"
    fi
    exit 1
fi
