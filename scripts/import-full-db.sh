#!/bin/bash
# Script to import FULL database backup to infralabs-deploy
# Use this to restore complete database from main project backup
# WARNING: This will REPLACE all existing data!

set -e

CONTAINER_NAME=${CONTAINER_NAME:-infralabs_db}
DB_NAME=${DB_NAME:-infralabs}
DB_USER=${DB_USER:-infralabs_user}
POSTGRES_USER=${POSTGRES_USER:-postgres}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📥 Importing FULL database to infralabs-deploy...${NC}"
echo ""

# Check if dump file is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Dump file not specified!${NC}"
    echo ""
    echo "Usage: $0 <dump_file.sql>"
    echo ""
    echo "Example:"
    echo "  $0 ./backups/infralabs_full_db_20250110_120000.sql"
    echo ""
    echo "Available backups:"
    if [ -d "./backups" ]; then
        ls -lh ./backups/infralabs_full_db_*.sql 2>/dev/null | tail -5 || echo "   No backups found in ./backups/"
    else
        echo "   ./backups/ directory does not exist"
    fi
    exit 1
fi

DUMP_FILE="$1"

# Check if dump file exists
if [ ! -f "${DUMP_FILE}" ]; then
    echo -e "${RED}❌ Error: Dump file not found: ${DUMP_FILE}${NC}"
    exit 1
fi

FILE_SIZE=$(du -h "${DUMP_FILE}" | cut -f1)
echo "📦 Database dump file:"
echo "   File: ${DUMP_FILE}"
echo "   Size: ${FILE_SIZE}"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ Container '${CONTAINER_NAME}' does not exist!${NC}"
    echo "   Please start the database container first:"
    echo "   docker-compose up -d db"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Container '${CONTAINER_NAME}' is not running. Starting it...${NC}"
    docker-compose up -d db
    
    echo "⏳ Waiting for database to be ready..."
    for i in {1..30}; do
        if docker exec ${CONTAINER_NAME} pg_isready -U ${DB_USER} > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Database is ready!${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}❌ Database failed to start!${NC}"
            exit 1
        fi
        sleep 1
    done
fi

echo ""
echo -e "${RED}⚠️  WARNING: This will REPLACE all existing data in the database!${NC}"
echo ""
echo "   This includes:"
echo "   • All users and authentication data"
echo "   • All courses, modules, lessons, exercises"
echo "   • All user progress and achievements"
echo "   • All sandbox sessions"
echo "   • Everything else in the database"
echo ""
echo -e "${YELLOW}   The current database will be DROPPED and RECREATED!${NC}"
echo ""

read -p "Are you absolutely sure you want to continue? Type 'yes' to confirm: " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    echo "Import cancelled."
    exit 0
fi

echo ""
echo "🔄 Preparing database for import..."

# Copy dump file to container
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CONTAINER_DUMP_PATH="/tmp/restore_full_db_${TIMESTAMP}.sql"

echo "   Copying dump file to container..."
docker cp "${DUMP_FILE}" "${CONTAINER_NAME}:${CONTAINER_DUMP_PATH}"

# Check if dump uses --create flag (creates database)
HAS_CREATE=$(docker exec ${CONTAINER_NAME} head -50 "${CONTAINER_DUMP_PATH}" | grep -c "CREATE DATABASE" || echo "0")

if [ "${HAS_CREATE}" -gt 0 ]; then
    echo "   Dump file contains CREATE DATABASE - adjusting for existing database..."
    
    # Create temporary script to handle restore
    docker exec ${CONTAINER_NAME} bash -c "cat > /tmp/restore_script.sh <<'SCRIPT_EOF'
#!/bin/bash
set -e

# Connect to postgres database (not infralabs) to drop/recreate
psql -U ${POSTGRES_USER} -d postgres <<EOF
-- Terminate existing connections
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '${DB_NAME}'
  AND pid <> pg_backend_pid();

-- Drop and recreate database
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF

# Now restore the dump (skip CREATE DATABASE line)
grep -v \"^CREATE DATABASE\" ${CONTAINER_DUMP_PATH} | \
grep -v \"^\\\\connect\" | \
psql -U ${DB_USER} -d ${DB_NAME} -v ON_ERROR_STOP=1
SCRIPT_EOF
chmod +x /tmp/restore_script.sh"

    echo "   Restoring database (this may take a while)..."
    RESTORE_OUTPUT=$(docker exec ${CONTAINER_NAME} bash /tmp/restore_script.sh 2>&1)
    
else
    # Dump doesn't create database, just restore directly
    echo "   Restoring database (this may take a while)..."
    
    # Drop all existing connections first
    docker exec ${CONTAINER_NAME} psql -U ${POSTGRES_USER} -d postgres -c \
        "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${DB_NAME}' AND pid <> pg_backend_pid();" \
        2>/dev/null || true
    
    # Restore the dump (use the file already copied to container)
    RESTORE_OUTPUT=$(docker exec ${CONTAINER_NAME} bash -c "cat ${CONTAINER_DUMP_PATH} | psql -U ${DB_USER} -d ${DB_NAME}" 2>&1)
fi

# Clean up
docker exec ${CONTAINER_NAME} rm -f "${CONTAINER_DUMP_PATH}" /tmp/restore_script.sh 2>/dev/null || true

# Check for errors
FATAL_ERRORS=$(echo "${RESTORE_OUTPUT}" | grep -c "FATAL:" 2>/dev/null || echo "0")
ERROR_COUNT=$(echo "${RESTORE_OUTPUT}" | grep -c "^ERROR:" 2>/dev/null || echo "0")

if [ "${FATAL_ERRORS}" -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Import failed with fatal errors!${NC}"
    echo "${RESTORE_OUTPUT}" | grep "FATAL:" | head -10
    exit 1
fi

# Show summary
echo ""
echo "📊 Verifying import..."

# Count tables
TABLE_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" \
    2>/dev/null | tr -d ' ' || echo "0")

# Count records in main tables (if they exist)
COURSE_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
    "SELECT COUNT(*) FROM courses;" 2>/dev/null | tr -d ' ' || echo "N/A")
USER_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
    "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "N/A")
MODULE_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
    "SELECT COUNT(*) FROM modules;" 2>/dev/null | tr -d ' ' || echo "N/A")
LESSON_COUNT=$(docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -t -c \
    "SELECT COUNT(*) FROM lessons;" 2>/dev/null | tr -d ' ' || echo "N/A")

echo ""
echo -e "${GREEN}✅ Database restored successfully!${NC}"
echo ""
echo "📋 Import Summary:"
echo "   Tables:    ${TABLE_COUNT}"
echo "   Users:     ${USER_COUNT}"
echo "   Courses:   ${COURSE_COUNT}"
echo "   Modules:   ${MODULE_COUNT}"
echo "   Lessons:   ${LESSON_COUNT}"
echo ""

if [ "${ERROR_COUNT}" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: ${ERROR_COUNT} errors occurred during import${NC}"
    echo "   (Some errors may be expected, e.g., if objects already exist)"
    echo "${RESTORE_OUTPUT}" | grep "^ERROR:" | head -5
    echo ""
fi

echo "🔄 Restarting web service to apply changes..."
docker-compose restart web 2>/dev/null || echo "   (Web service restart skipped - restart manually if needed)"

echo ""
echo -e "${GREEN}✅ Done!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify the application is working: http://localhost"
echo "  2. Check admin panel: http://localhost/admin/"
echo "  3. Test user login with credentials from restored database"
