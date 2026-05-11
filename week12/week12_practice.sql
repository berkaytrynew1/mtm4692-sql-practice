-- ============================================================
-- MTM4692 Applied SQL — Week 12 Practice
-- Topic: Cursors - Row-by-Row Processing & Set-Based Alternatives
-- ============================================================
-- Run with: sqlite3 -header -column databases/university.db < week12_practice.sql
-- ============================================================

PRAGMA foreign_keys = ON;
.headers on
.mode column

-- ============================================================
-- SECTION 1: Window Functions Replace Cursors (Running Totals)
-- ============================================================

.print '\n=== Window Function: Running Totals (Instead of Cursor) ==='

-- Instead of a cursor loop that accumulates:
-- Use SUM() OVER() — 100x faster!

SELECT student_id, gpa,
       SUM(gpa) OVER (
           PARTITION BY dept_id
           ORDER BY student_id
           ROWS UNBOUNDED PRECEDING
       ) AS dept_running_total
FROM student
ORDER BY dept_id, student_id;

-- ============================================================
-- SECTION 2: Window Functions - Ranking per Department
-- ============================================================

.print '\n=== Window Function: Ranking Students by Department ==='

-- Instead of a cursor that ranks students per department:
-- Use ROW_NUMBER() OVER()

SELECT first_name, last_name, dept_id, gpa,
       ROW_NUMBER() OVER (
           PARTITION BY dept_id ORDER BY gpa DESC
       ) AS dept_rank
FROM student
ORDER BY dept_id, dept_rank;

-- ============================================================
-- SECTION 3: Conditional Aggregation (Instead of Cursor)
-- ============================================================

.print '\n=== Conditional Aggregation: Scholarship Calculation ==='

-- Instead of a cursor loop that calculates scholarship per student:
-- Use CASE + SUM() — set-based and much faster!

SELECT d.dept_id, 
       d.dept_name,
       COUNT(*) AS student_count,
       SUM(CASE
           WHEN gpa >= 3.7 THEN 500
           WHEN gpa >= 3.0 THEN 300
           WHEN gpa >= 2.0 THEN 100
           ELSE 0
       END) AS total_scholarship,
       ROUND(AVG(gpa), 2) AS avg_gpa
FROM department d
LEFT JOIN student s ON d.dept_id = s.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY total_scholarship DESC;

-- ============================================================
-- SECTION 4: Conditional Updates (Instead of Cursor Loop)
-- ============================================================

.print '\n=== Set-Based Update: Status by GPA (Instead of Cursor) ==='

-- NOTE: SQLite 3.35.0+ supports IF NOT EXISTS in ADD COLUMN
-- For older versions, just add the column (it must not already exist)

-- !!! run this once to add the column then uncomment to avoid error on subsequent runs.!!!
ALTER TABLE student ADD COLUMN status TEXT DEFAULT 'active';

-- ❌ SLOW: Cursor approach (row-by-row) would do:
--    OPEN cur;
--    LOOP
--        FETCH cur INTO v_id, v_gpa;
--        IF v_gpa < 2.0 THEN
--            UPDATE student SET status = 'probation' WHERE student_id = v_id;
--        END IF;
--    END LOOP;

-- ✅ FAST: Set-based approach (one statement)
UPDATE student SET status =
    CASE
        WHEN gpa < 2.0 THEN 'probation'
        WHEN gpa < 3.0 THEN 'good standing'
        ELSE 'honor'
    END;

-- Verify the update
.print '\n=== Verification: Student Status by GPA ==='
SELECT status, COUNT(*) AS count, ROUND(AVG(gpa), 2) AS avg_gpa
FROM student
GROUP BY status
ORDER BY avg_gpa DESC;

-- ============================================================
-- SECTION 5: Recursive CTE as Cursor Alternative (SQLite)
-- ============================================================

.print '\n=== Window Functions: Ranking with Performance Categories ==='

-- Instead of a complex recursive CTE, use simple window functions with CASE
-- Example: Ranking students with performance categories

SELECT s.student_id,
       s.first_name,
       s.last_name,
       s.gpa,
       s.dept_id,
       ROW_NUMBER() OVER (PARTITION BY s.dept_id ORDER BY s.gpa DESC) AS dept_rank,
       COUNT(*) OVER (PARTITION BY s.dept_id) AS total_in_dept,
       CASE
           WHEN ROW_NUMBER() OVER (PARTITION BY s.dept_id ORDER BY s.gpa DESC) = 1 THEN 'Top Student'
           WHEN ROW_NUMBER() OVER (PARTITION BY s.dept_id ORDER BY s.gpa DESC) <= 3 THEN 'High Performer'
           WHEN ROW_NUMBER() OVER (PARTITION BY s.dept_id ORDER BY s.gpa DESC) <= 
                CAST(COUNT(*) OVER (PARTITION BY s.dept_id) * 0.5 AS INT) THEN 'Above Average'
           ELSE 'Below Average'
       END AS performance_category
FROM student s
WHERE s.dept_id IS NOT NULL
ORDER BY s.dept_id, dept_rank
LIMIT 20;

-- ============================================================
-- SECTION 6: GROUP_CONCAT for Reports (Instead of Cursor)
-- ============================================================

.print '\n=== GROUP_CONCAT: Building Reports Without Cursor Loop ==='

-- Instead of cursoring through rows to build a report:
-- Use GROUP_CONCAT to aggregate string values

SELECT d.dept_id,
       d.dept_name,
       COUNT(s.student_id) AS student_count,
       ROUND(AVG(s.gpa), 2) AS avg_gpa,
       GROUP_CONCAT(s.first_name, ', ') AS student_list
FROM department d
LEFT JOIN student s ON d.dept_id = s.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY d.dept_id;

-- ============================================================
-- SECTION 7: Performance Summary - Cursor vs Set-Based
-- ============================================================

.print '\n=== Performance Comparison: Cursor vs Set-Based ==='

.print '\n--- Example 1: Running Total ---'
.print 'Cursor: ~20 lines of code, processes row-by-row'
.print 'Set-Based: 1 line with SUM() OVER()'
.print 'Speed: Set-based is 10-100x FASTER'

.print '\n--- Example 2: Conditional Updates ---'
.print 'Cursor: LOOP with IF conditions (slow)'
.print 'Set-Based: UPDATE with CASE (fast)'

.print '\n--- Example 3: Ranking Rows ---'
.print 'Cursor: Manual counter/ranking logic'
.print 'Set-Based: ROW_NUMBER() OVER()'

.print '\n--- Example 4: Aggregation ---'
.print 'Cursor: Accumulator variable in loop'
.print 'Set-Based: SUM(), AVG(), COUNT()'

-- ============================================================
-- KEY CONCEPTS
-- ============================================================

.print '\n=== KEY CONCEPTS TO REMEMBER ==='

.print '\n1. WHEN TO USE CURSORS (MySQL):'
.print '   - Calling another procedure per row'
.print '   - Different actions per row (complex logic)'
.print '   - Row-by-row external system calls'

.print '\n2. WHEN TO USE SET-BASED (ALWAYS PREFER!):'
.print '   - Single SQL statements (fastest)'
.print '   - Window functions (running totals, ranks)'
.print '   - Conditional aggregation (CASE in SUM)'
.print '   - Recursive CTEs (sequential processing)'

.print '\n3. SQLite ALTERNATIVES (No cursors in SQLite):'
.print '   - Window functions: SUM() OVER, ROW_NUMBER() OVER'
.print '   - Recursive CTEs for sequential processing'
.print '   - Conditional aggregation: CASE within aggregates'
.print '   - GROUP_CONCAT for string aggregation'
.print '   - Application-level loops (Python, etc.)'

.print '\n4. DECLARATION ORDER (MySQL - MANDATORY):'
.print '   1. Variables first'
.print '   2. Cursors second'
.print '   3. Handlers third'
.print '   4. Executable code last'

.print '\n5. PERFORMANCE RULE:'
.print '   Set-based is typically 10-100x FASTER than cursors!'
.print '   Always look for a set-based solution first!'

.print '\n============================================================'

-- ============================================================
-- PRACTICAL CURSOR EXAMPLES (MySQL Only)
-- ============================================================
--  
-- Watch the video for conceptual explanation of MySQL cursors and how to implement them:
-- https://www.youtube.com/watch?v=RHRjLd0bEaQ 
-- HOW TO RUN IN MYSQL:
-- 1. Copy the DELIMITER // ... DELIMITER ; block
-- 2. Paste into MySQL Workbench, MySQL CLI, or DBeaver
-- 3. Run the CREATE PROCEDURE statement
-- 4. Then execute: CALL procedure_name();
--
-- ============================================================

-- ============================================================
-- PRACTICE EXERCISE 1: Basic Cursor Loop
-- ============================================================
-- Goal: Loop through students and display their info
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE basic_cursor_example()
-- BEGIN
--     DECLARE v_name VARCHAR(100);
--     DECLARE v_gpa DECIMAL(3,2);
--     DECLARE v_done INT DEFAULT 0;
--
--     DECLARE student_cur CURSOR FOR
--         SELECT CONCAT(first_name, ' ', last_name), gpa
--         FROM student
--         ORDER BY gpa DESC;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     OPEN student_cur;
--
--     loop_label: LOOP
--         FETCH student_cur INTO v_name, v_gpa;
--         IF v_done = 1 THEN LEAVE loop_label; END IF;
--
--         -- Process each row
--         SELECT CONCAT(v_name, ' - GPA: ', v_gpa) AS student_info;
--     END LOOP;
--
--     CLOSE student_cur;
-- END //
-- DELIMITER ;
--
-- CALL basic_cursor_example();

-- ============================================================
-- PRACTICE EXERCISE 2: Cursor with CASE Logic
-- ============================================================
-- Goal: Use cursor to assign grades based on GPA
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE cursor_with_case()
-- BEGIN
--     DECLARE v_name VARCHAR(100);
--     DECLARE v_gpa DECIMAL(3,2);
--     DECLARE v_grade VARCHAR(2);
--     DECLARE v_done INT DEFAULT 0;
--
--     DECLARE cur CURSOR FOR
--         SELECT CONCAT(first_name, ' ', last_name), gpa
--         FROM student
--         ORDER BY gpa DESC;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     OPEN cur;
--
--     read_loop: LOOP
--         FETCH cur INTO v_name, v_gpa;
--         IF v_done THEN LEAVE read_loop; END IF;
--
--         -- Assign grade based on GPA
--         SET v_grade = CASE
--             WHEN v_gpa >= 3.7 THEN 'A'
--             WHEN v_gpa >= 3.0 THEN 'B'
--             WHEN v_gpa >= 2.0 THEN 'C'
--             ELSE 'F'
--         END;
--
--         SELECT CONCAT(v_name, ' (', v_gpa, ') = ', v_grade) AS grade_assignment;
--     END LOOP;
--
--     CLOSE cur;
-- END //
-- DELIMITER ;
--
-- CALL cursor_with_case();

-- ============================================================
-- PRACTICE EXERCISE 3: Cursor with Accumulation
-- ============================================================
-- Goal: Count students and calculate running total
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE cursor_with_accumulation()
-- BEGIN
--     DECLARE v_name VARCHAR(100);
--     DECLARE v_count INT DEFAULT 0;
--     DECLARE v_done INT DEFAULT 0;
--
--     DECLARE cur CURSOR FOR
--         SELECT first_name FROM student ORDER BY first_name;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     OPEN cur;
--
--     count_loop: LOOP
--         FETCH cur INTO v_name;
--         IF v_done THEN LEAVE count_loop; END IF;
--
--         SET v_count = v_count + 1;
--         SELECT CONCAT(v_count, '. ', v_name) AS student_list;
--     END LOOP;
--
--     CLOSE cur;
--     SELECT CONCAT('Total students: ', v_count) AS summary;
-- END //
-- DELIMITER ;
--
-- CALL cursor_with_accumulation();

-- ============================================================
-- PRACTICE EXERCISE 4: Cursor with Conditional Update
-- ============================================================
-- Goal: Update student status based on GPA using cursor
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE cursor_conditional_update()
-- BEGIN
--     DECLARE v_id INT;
--     DECLARE v_gpa DECIMAL(3,2);
--     DECLARE v_status VARCHAR(50);
--     DECLARE v_done INT DEFAULT 0;
--     DECLARE v_count INT DEFAULT 0;
--
--     DECLARE cur CURSOR FOR
--         SELECT student_id, gpa FROM student;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     OPEN cur;
--
--     update_loop: LOOP
--         FETCH cur INTO v_id, v_gpa;
--         IF v_done THEN LEAVE update_loop; END IF;
--
--         -- Determine status
--         SET v_status = CASE
--             WHEN v_gpa >= 3.5 THEN 'honor'
--             WHEN v_gpa >= 2.0 THEN 'good standing'
--             ELSE 'probation'
--         END;
--
--         -- Update the student record
--         UPDATE student SET status = v_status WHERE student_id = v_id;
--         SET v_count = v_count + 1;
--     END LOOP;
--
--     CLOSE cur;
--     SELECT CONCAT('Updated ', v_count, ' students') AS result;
-- END //
-- DELIMITER ;
--
-- CALL cursor_conditional_update();

-- ============================================================
-- PRACTICE EXERCISE 5: Cursor with Temporary Table
-- ============================================================
-- Goal: Populate a temporary table with processed data
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE cursor_to_temp_table()
-- BEGIN
--     DECLARE v_name VARCHAR(100);
--     DECLARE v_gpa DECIMAL(3,2);
--     DECLARE v_rank INT DEFAULT 0;
--     DECLARE v_done INT DEFAULT 0;
--
--     DECLARE cur CURSOR FOR
--         SELECT CONCAT(first_name, ' ', last_name), gpa
--         FROM student
--         ORDER BY gpa DESC;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     -- Create temporary table
--     DROP TEMPORARY TABLE IF EXISTS student_rankings;
--     CREATE TEMPORARY TABLE student_rankings (
--         rank_num INT,
--         student_name VARCHAR(100),
--         gpa DECIMAL(3,2),
--         honor_status VARCHAR(50)
--     );
--
--     OPEN cur;
--
--     rank_loop: LOOP
--         FETCH cur INTO v_name, v_gpa;
--         IF v_done THEN LEAVE rank_loop; END IF;
--
--         SET v_rank = v_rank + 1;
--
--         INSERT INTO student_rankings VALUES (
--             v_rank,
--             v_name,
--             v_gpa,
--             IF(v_gpa >= 3.5, 'Honor Roll', 'Regular')
--         );
--     END LOOP;
--
--     CLOSE cur;
--
--     -- Display results
--     SELECT * FROM student_rankings;
-- END //
-- DELIMITER ;
--
-- CALL cursor_to_temp_table();

-- ============================================================
-- CHALLENGE EXERCISE: Department Processing
-- ============================================================
-- Goal: Process each department separately (nested-like logic)
-- 
-- Copy and paste this entire block into MySQL:
--
-- DELIMITER //
-- CREATE PROCEDURE process_by_department()
-- BEGIN
--     DECLARE v_dept_id INT;
--     DECLARE v_dept_name VARCHAR(100);
--     DECLARE v_count INT DEFAULT 0;
--     DECLARE v_avg_gpa DECIMAL(3,2);
--     DECLARE v_done INT DEFAULT 0;
--
--     DECLARE dept_cur CURSOR FOR
--         SELECT dept_id, dept_name FROM department;
--
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
--     OPEN dept_cur;
--
--     dept_loop: LOOP
--         FETCH dept_cur INTO v_dept_id, v_dept_name;
--         IF v_done THEN LEAVE dept_loop; END IF;
--
--         -- Get stats for this department
--         SELECT COUNT(*) INTO v_count
--         FROM student WHERE dept_id = v_dept_id;
--
--         SELECT AVG(gpa) INTO v_avg_gpa
--         FROM student WHERE dept_id = v_dept_id;
--
--         -- Display results
--         SELECT CONCAT(
--             'Department: ', v_dept_name,
--             ' | Students: ', v_count,
--             ' | Avg GPA: ', ROUND(v_avg_gpa, 2)
--         ) AS dept_summary;
--     END LOOP;
--
--     CLOSE dept_cur;
-- END //
-- DELIMITER ;
--
-- CALL process_by_department();

-- ============================================================
-- COMMON ERRORS TO WATCH FOR
-- ============================================================
--
-- ERROR 1: Wrong Declaration Order
-- ❌ WRONG:
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
--     DECLARE done INT DEFAULT 0;
--     DECLARE cur CURSOR FOR ...;
--
-- ✅ CORRECT:
--     DECLARE done INT DEFAULT 0;
--     DECLARE cur CURSOR FOR ...;
--     DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
--
-- ERROR 2: Missing LEAVE label
-- ❌ WRONG: IF v_done THEN LEAVE; END IF;
-- ✅ CORRECT: IF v_done THEN LEAVE loop_label; END IF;
--
-- ERROR 3: FETCH past end of cursor without handler
-- ❌ WRONG: No DECLARE CONTINUE HANDLER
-- ✅ CORRECT: DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
--
-- ERROR 4: Forgetting OPEN or CLOSE
-- ❌ WRONG: DECLARE cur CURSOR ... FETCH cur INTO ...;
-- ✅ CORRECT: DECLARE cur CURSOR ... OPEN cur; FETCH cur INTO ...;
--
-- ============================================================
-- SUMMARY
-- ============================================================
--
-- Remember: These are for LEARNING ONLY!
-- 
-- In production, ALWAYS use set-based operations:
--   - Window functions (SUM() OVER, ROW_NUMBER() OVER)
--   - Conditional aggregation (CASE within SUM, COUNT, etc.)
--   - Recursive CTEs (for sequential processing)
--   - Single UPDATE/DELETE statements
--
-- Cursors are 10-100x SLOWER than set-based approaches!
-- Use them only when absolutely necessary.
--
-- ============================================================

