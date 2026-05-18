-- ============================================================
-- MTM4692 Applied SQL — Week 13 Practice
-- Topic: ACID Transactions & Triggers in SQLite
-- ============================================================
-- Run with: sqlite3 university.db < week13_practice.sql
-- ============================================================

PRAGMA foreign_keys = ON;
.headers on
.mode column

-- ============================================================
-- SECTION 1: Basic Transactions
-- ============================================================

.print '\n=== Basic Transaction: COMMIT ==='

BEGIN TRANSACTION;
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Trans', 'Commit', 'trans.commit@test.edu', 1, 3.5);
COMMIT;

SELECT * FROM student WHERE first_name = 'Trans';

.print '\n=== Basic Transaction: ROLLBACK ==='

BEGIN TRANSACTION;
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Trans', 'Rollback', 'trans.rollback@test.edu', 1, 2.0);
-- Check it exists inside transaction
SELECT COUNT(*) AS 'Inside TX' FROM student WHERE last_name = 'Rollback';
ROLLBACK;

-- After rollback: should be 0
SELECT COUNT(*) AS 'After Rollback' FROM student WHERE last_name = 'Rollback';

-- Cleanup
DELETE FROM student WHERE first_name = 'Trans';

-- ============================================================
-- SECTION 2: SAVEPOINT — Partial Rollback
-- ============================================================

.print '\n=== SAVEPOINT Demo ==='

BEGIN TRANSACTION;

-- Insert a student
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Save1', 'Keep', 'save1.keep@test.edu', 1, 3.0);

SAVEPOINT sp1;

-- Insert another
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Save2', 'Discard', 'save2.discard@test.edu', 1, 3.5);

SAVEPOINT sp2;

-- Insert a third
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Save3', 'AlsoDiscard', 'save3.alsodiscard@test.edu', 1, 2.5);

-- Rollback to sp1 (discard Save2 and Save3)
ROLLBACK TO sp1;

-- Only Save1 should remain
COMMIT;

.print '\n=== After SAVEPOINT test ==='
SELECT first_name, last_name FROM student WHERE first_name LIKE 'Save%';
-- Should show only Save1

-- Cleanup
DELETE FROM student WHERE first_name LIKE 'Save%';

-- ============================================================
-- SECTION 3: Nested SAVEPOINTs
-- ============================================================

.print '\n=== Nested SAVEPOINTs ==='

BEGIN TRANSACTION;

INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Level0', 'Base', 'level0.base@test.edu', 1, 3.0);

SAVEPOINT level1;
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Level1', 'First', 'level1.first@test.edu', 1, 3.2);

SAVEPOINT level2;
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Level2', 'Second', 'level2.second@test.edu', 1, 3.4);

SAVEPOINT level3;
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Level3', 'Third', 'level3.third@test.edu', 1, 3.6);

-- Rollback only level3
ROLLBACK TO level3;

-- Keep Level0, Level1, Level2
COMMIT;

SELECT first_name FROM student WHERE first_name LIKE 'Level%' ORDER BY first_name;

-- Cleanup
DELETE FROM student WHERE first_name LIKE 'Level%';

-- ============================================================
-- SECTION 4: BEFORE INSERT Trigger — Validation
-- ============================================================

.print '\n=== BEFORE INSERT Trigger: GPA Validation ==='

DROP TRIGGER IF EXISTS validate_student_insert;
CREATE TRIGGER validate_student_insert
    BEFORE INSERT ON student
BEGIN
    -- Validate GPA range
    SELECT CASE
        WHEN NEW.gpa < 0.0 OR NEW.gpa > 4.0
        THEN RAISE(ABORT, 'ERROR: GPA must be between 0.0 and 4.0')
    END;

    -- Validate name is not empty
    SELECT CASE
        WHEN LENGTH(TRIM(NEW.first_name)) = 0
        THEN RAISE(ABORT, 'ERROR: First name cannot be empty')
    END;

    -- Validate department exists
    SELECT CASE
        WHEN (SELECT COUNT(*) FROM department WHERE dept_id = NEW.dept_id) = 0
        THEN RAISE(ABORT, 'ERROR: Department does not exist')
    END;
END;

-- Test valid insert
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Valid', 'Student', 'valid.student@test.edu', 1, 3.5);
.print 'Valid insert succeeded'

-- Test invalid GPA (should fail)
-- INSERT INTO student VALUES (NULL, 'Bad', 'GPA', 1, 5.0);
-- Would produce: ERROR: GPA must be between 0.0 and 4.0

-- Cleanup
DELETE FROM student WHERE first_name = 'Valid';

-- ============================================================
-- SECTION 5: BEFORE UPDATE Trigger — Change Validation
-- ============================================================

.print '\n=== BEFORE UPDATE Trigger: GPA Change Guard ==='

DROP TRIGGER IF EXISTS validate_gpa_update;
CREATE TRIGGER validate_gpa_update
    BEFORE UPDATE OF gpa ON student
    WHEN NEW.gpa < 0.0 OR NEW.gpa > 4.0
BEGIN
    SELECT RAISE(ABORT, 'ERROR: GPA must be between 0.0 and 4.0');
END;

-- Prevent large GPA drops (more than 1.5 in one update)
DROP TRIGGER IF EXISTS prevent_large_gpa_drop;
CREATE TRIGGER prevent_large_gpa_drop
    BEFORE UPDATE OF gpa ON student
    WHEN OLD.gpa - NEW.gpa > 1.5
BEGIN
    SELECT RAISE(ABORT, 'ERROR: GPA cannot drop by more than 1.5 in one update');
END;

.print 'Update validation triggers created'

-- ============================================================
-- SECTION 6: AFTER Trigger — Audit Log
-- ============================================================

.print '\n=== AFTER Triggers: Audit Logging ==='

-- Create audit log table
DROP TABLE IF EXISTS audit_log;
CREATE TABLE audit_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL,
    action TEXT NOT NULL,
    record_id INTEGER,
    old_values TEXT,
    new_values TEXT,
    timestamp TEXT DEFAULT (datetime('now'))
);

-- Log INSERT
DROP TRIGGER IF EXISTS log_student_insert;
CREATE TRIGGER log_student_insert
    AFTER INSERT ON student
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, new_values)
    VALUES ('student', 'INSERT', NEW.student_id,
            'name=' || NEW.first_name || ' ' || NEW.last_name ||
            ', dept=' || NEW.dept_id || ', gpa=' || NEW.gpa);
END;

-- Log UPDATE (only when GPA changes)
DROP TRIGGER IF EXISTS log_student_update;
CREATE TRIGGER log_student_update
    AFTER UPDATE ON student
    WHEN OLD.gpa != NEW.gpa OR OLD.first_name != NEW.first_name
         OR OLD.last_name != NEW.last_name
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_values, new_values)
    VALUES ('student', 'UPDATE', NEW.student_id,
            'name=' || OLD.first_name || ' ' || OLD.last_name ||
            ', gpa=' || OLD.gpa,
            'name=' || NEW.first_name || ' ' || NEW.last_name ||
            ', gpa=' || NEW.gpa);
END;

-- Log DELETE
DROP TRIGGER IF EXISTS log_student_delete;
CREATE TRIGGER log_student_delete
    AFTER DELETE ON student
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_values)
    VALUES ('student', 'DELETE', OLD.student_id,
            'name=' || OLD.first_name || ' ' || OLD.last_name ||
            ', gpa=' || OLD.gpa);
END;

-- Test the audit triggers
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('Audit', 'Test', 'audit.test@test.edu', 1, 3.0);

UPDATE student SET gpa = 3.5
WHERE first_name = 'Audit' AND last_name = 'Test';

DELETE FROM student WHERE first_name = 'Audit' AND last_name = 'Test';

.print '\n=== Audit Log Contents ==='
SELECT * FROM audit_log ORDER BY log_id;

-- ============================================================
-- SECTION 7: Trigger for Automatic Timestamp
-- ============================================================

.print '\n=== Auto-Timestamp Trigger ==='

-- Create a table with timestamps
DROP TABLE IF EXISTS notes;
CREATE TABLE notes (
    note_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Auto-update timestamp on modification
DROP TRIGGER IF EXISTS notes_update_timestamp;
CREATE TRIGGER notes_update_timestamp
    AFTER UPDATE ON notes
BEGIN
    UPDATE notes SET updated_at = datetime('now')
    WHERE note_id = NEW.note_id;
END;

INSERT INTO notes (title, content) VALUES ('Test Note', 'Original content');
SELECT * FROM notes;

-- Simulate a delay, then update
UPDATE notes SET content = 'Updated content' WHERE note_id = 1;
SELECT * FROM notes;

DROP TABLE notes;

-- ============================================================
-- SECTION 8: INSTEAD OF Trigger (SQLite-specific for views)
-- ============================================================

.print '\n=== INSTEAD OF Trigger on View ==='

-- Create a view
DROP VIEW IF EXISTS student_dept_view;
CREATE VIEW student_dept_view AS
SELECT s.student_id, s.first_name, s.last_name,
       d.dept_name, s.gpa
FROM student s
JOIN department d ON s.dept_id = d.dept_id;

-- Make the view "updatable" with INSTEAD OF trigger
DROP TRIGGER IF EXISTS update_student_via_view;
CREATE TRIGGER update_student_via_view
    INSTEAD OF UPDATE ON student_dept_view
BEGIN
    UPDATE student
    SET first_name = NEW.first_name,
        last_name = NEW.last_name,
        gpa = NEW.gpa
    WHERE student_id = OLD.student_id;
END;

.print 'INSTEAD OF trigger created for view updates'

-- ============================================================
-- SECTION 9: Transaction + Trigger Interaction
-- ============================================================

.print '\n=== Transaction + Trigger ==='

-- Clear audit log
DELETE FROM audit_log;

BEGIN TRANSACTION;

-- These inserts will fire the audit trigger
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('TX1', 'Student', 'tx1.student@test.edu', 1, 3.0);
INSERT INTO student (first_name, last_name, email, dept_id, gpa)
VALUES ('TX2', 'Student', 'tx2.student@test.edu', 1, 3.5);

-- Check audit log INSIDE transaction
.print '\n--- Audit log inside transaction ---'
SELECT * FROM audit_log;

ROLLBACK;

-- After rollback: both inserts AND their audit logs are undone!
.print '\n--- Audit log after ROLLBACK ---'
SELECT COUNT(*) AS audit_entries FROM audit_log;

-- ============================================================
-- SECTION 10: Comprehensive Exercise
-- ============================================================

.print '\n=== Comprehensive: Order Processing System ==='

-- Create orders table if it doesn't exist
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    order_date TEXT DEFAULT (datetime('now'))
);

-- Clear audit log
DELETE FROM audit_log;

-- Create order processing trigger
DROP TRIGGER IF EXISTS log_order_insert;
CREATE TRIGGER log_order_insert
    AFTER INSERT ON orders
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, new_values)
    VALUES ('orders', 'INSERT', NEW.order_id,
            'customer=' || NEW.customer_id ||
            ', date=' || COALESCE(NEW.order_date, 'NULL'));
END;

-- Simulate a multi-step order process with savepoints
BEGIN TRANSACTION;

-- Step 1: Create order
SAVEPOINT order_creation;

-- Check if we have orders table data
SELECT COUNT(*) AS existing_orders FROM orders;

-- Step 2: Add items (savepoint so we can retry)
SAVEPOINT item_addition;

-- Step 3: Finalize
COMMIT;

-- Final audit report
.print '\n=== Final Audit Report ==='
SELECT action, table_name, record_id,
       COALESCE(new_values, old_values) AS details,
       timestamp
FROM audit_log
ORDER BY log_id DESC
LIMIT 10;

-- ============================================================
-- SECTION 11: List All Triggers
-- ============================================================

.print '\n=== All Triggers in Database ==='
SELECT name, tbl_name AS 'table', sql
FROM sqlite_master
WHERE type = 'trigger'
ORDER BY tbl_name, name;

-- Cleanup
DROP TRIGGER IF EXISTS validate_student_insert;
DROP TRIGGER IF EXISTS validate_gpa_update;
DROP TRIGGER IF EXISTS prevent_large_gpa_drop;
DROP TRIGGER IF EXISTS log_student_insert;
DROP TRIGGER IF EXISTS log_student_update;
DROP TRIGGER IF EXISTS log_student_delete;
DROP TRIGGER IF EXISTS log_order_insert;
DROP TRIGGER IF EXISTS update_student_via_view;
DROP VIEW IF EXISTS student_dept_view;
DROP TABLE IF EXISTS audit_log;

.print '\n✅ Week 13 practice complete!'
