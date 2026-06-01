-- ============================================================
-- MTM4692 Applied SQL — Week 14 Practice
-- Topic: Backup, Restore & Database Maintenance in SQLite
-- ============================================================
-- Run with: sqlite3 university.db < week14_practice.sql
-- ============================================================

PRAGMA foreign_keys = ON;
.headers on
.mode column

-- ============================================================
-- SECTION 1: Database Information & Health Check
-- ============================================================

.print '\n=== Database Health Check ==='

-- Check database integrity
PRAGMA integrity_check;

-- Database size info
.print '\n=== Database File Info ==='
PRAGMA page_size;
PRAGMA page_count;
PRAGMA journal_mode;

-- ============================================================
-- SECTION 2: Table Statistics
-- ============================================================

.print '\n=== Table Statistics ==='

-- List all tables and row counts
SELECT name AS table_name,
       (SELECT COUNT(*) FROM sqlite_master sm2
        WHERE sm2.name = sm.name) AS exists_flag
FROM sqlite_master sm
WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
ORDER BY name;

-- Detailed table info
.print '\n=== Student Table Info ==='
PRAGMA table_info(student);

.print '\n=== Department Table Info ==='
PRAGMA table_info(department);

-- ============================================================
-- SECTION 3: Backup — .dump (Logical Backup)
-- ============================================================

.print '\n=== Creating Logical Backup (SQL Dump) ==='

-- Dump the entire schema
.print '\n--- Schema Only ---'
.schema

-- To create a full backup to file:
-- .output university_dump.sql
-- .dump
-- .output stdout
-- This creates a full SQL text backup

-- Dump specific table
.print '\n--- Student Table Dump ---'
.dump student

-- ============================================================
-- SECTION 4: Backup — .backup (Physical Backup)
-- ============================================================

.print '\n=== Physical Backup ==='

-- The .backup command creates a safe copy of the database
-- .backup university_backup.db

-- For a timestamped backup:
-- .backup university_backup_20260601.db

-- .backup is safe to use while the database is being read
-- It uses SQLite's Online Backup API

.print 'Use: .backup filename.db for physical backup'

-- ============================================================
-- SECTION 5: WAL Mode for Better Concurrency
-- ============================================================

.print '\n=== Journal Mode ==='

-- Check current journal mode
PRAGMA journal_mode;

-- WAL mode allows concurrent reads during writes
-- PRAGMA journal_mode = WAL;

-- WAL advantages:
-- - Readers don't block writers
-- - Writers don't block readers
-- - Better performance for most workloads
-- - Safe backups while database is in use

-- Other journal modes:
-- DELETE (default) - delete journal after commit
-- TRUNCATE - truncate journal (faster than delete)
-- PERSIST - journal header zeroed (fastest)
-- MEMORY - journal in RAM (not crash-safe!)
-- WAL - write-ahead logging (best for concurrency)

-- ============================================================
-- SECTION 6: VACUUM — Database Maintenance
-- ============================================================

.print '\n=== Database Maintenance: VACUUM ==='

-- VACUUM rebuilds the database file, reclaiming space
-- and defragmenting the database
-- Check size before
.print 'Before creating/deleting data:'
PRAGMA page_count;
PRAGMA freelist_count;

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS temp_data (
    id INTEGER PRIMARY KEY,
    data TEXT
);

WITH RECURSIVE nums(x) AS (
    SELECT 1
    UNION ALL
    SELECT x + 1
    FROM nums
    WHERE x < 10000
)
INSERT INTO temp_data
SELECT x, hex(randomblob(500))
FROM nums;

COMMIT;

.print 'After inserting data:'
PRAGMA page_count;
PRAGMA freelist_count;

-- Delete all rows and drop the table
BEGIN TRANSACTION;

DELETE FROM temp_data;
DROP TABLE temp_data;

COMMIT;

.print 'After deleting data (before VACUUM):'
PRAGMA page_count;
PRAGMA freelist_count;

VACUUM;

.print 'After VACUUM:'
PRAGMA page_count;
PRAGMA freelist_count;

-- ============================================================
-- SECTION 7: ANALYZE — Query Optimizer Statistics
-- ============================================================

.print '\n=== ANALYZE: Update Statistics ==='

-- ANALYZE gathers statistics about tables and indexes
-- The query optimizer uses these for better query plans
ANALYZE;

-- View statistics
SELECT * FROM sqlite_stat1 LIMIT 10;

-- ============================================================
-- SECTION 8: Index Maintenance
-- ============================================================

.print '\n=== Index Health ==='

-- List all indexes
SELECT name, tbl_name AS 'table'
FROM sqlite_master
WHERE type = 'index'
ORDER BY tbl_name, name;

-- Check index integrity
PRAGMA integrity_check;

-- Reindex to rebuild indexes
-- REINDEX;  -- Rebuilds all indexes
-- REINDEX student;  -- Rebuild indexes on student table

-- ============================================================
-- SECTION 9: Backup Verification
-- ============================================================

.print '\n=== Backup Verification Approach ==='

-- After restoring, verify with checksums
-- Compare row counts between original and backup:
SELECT 'student' AS tbl, COUNT(*) AS rows FROM student
UNION ALL
SELECT 'department', COUNT(*) FROM department
UNION ALL
SELECT 'course', COUNT(*) FROM course;

-- To verify a backup:
-- 1. Restore to a temp database
--    sqlite3 temp_verify.db < university_dump.sql
-- 2. Compare row counts
-- 3. Spot-check specific records
-- 4. Run integrity_check on restored database
--    PRAGMA integrity_check;

-- ============================================================
-- SECTION 10: Comprehensive Maintenance Script
-- ============================================================

.print '\n=== Comprehensive Maintenance Report ==='

-- 1. Integrity check
.print '\n--- 1. Integrity Check ---'
PRAGMA integrity_check;

-- 2. Database statistics
.print '\n--- 2. Database Statistics ---'
SELECT
    (SELECT COUNT(*) FROM sqlite_master WHERE type='table'
     AND name NOT LIKE 'sqlite_%') AS tables,
    (SELECT COUNT(*) FROM sqlite_master WHERE type='index') AS indexes,
    (SELECT COUNT(*) FROM sqlite_master WHERE type='trigger') AS triggers,
    (SELECT COUNT(*) FROM sqlite_master WHERE type='view') AS views;

-- 3. Table sizes (approximate)
.print '\n--- 3. Row Counts ---'
SELECT 'student' AS tbl, COUNT(*) AS rows FROM student
UNION ALL
SELECT 'department', COUNT(*) FROM department
UNION ALL
SELECT 'course', COUNT(*) FROM course
UNION ALL
SELECT 'instructor', COUNT(*) FROM instructor;

-- 4. Foreign key check
.print '\n--- 4. Foreign Key Check ---'
PRAGMA foreign_key_check;

-- 5. Compile options
.print '\n--- 5. SQLite Version ---'
SELECT sqlite_version() AS version;

-- 6. Update statistics
ANALYZE;

.print '\n✅ Week 14 practice complete!'
.print 'Backup & maintenance operations demonstrated.'
