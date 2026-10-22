CREATE DATABASE loanportfolio;
-- 1. INSPECT THE SOURCE DATABASE

USE loanportfolio;

SHOW TABLES;

DESCRIBE branch;
DESCRIBE customer;
DESCRIBE loan;
DESCRIBE repayment;

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'loanportfolio'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Check whether primary/foreign key constraints are declared.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'loanportfolio'
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- Record counts in the source database.
SELECT 'branch' AS table_name, COUNT(*) AS total_records FROM loanportfolio.branch
UNION ALL
SELECT 'customer', COUNT(*) FROM loanportfolio.customer
UNION ALL
SELECT 'loan', COUNT(*) FROM loanportfolio.loan
UNION ALL
SELECT 'repayment', COUNT(*) FROM loanportfolio.repayment;

-- Inspect the unusual prefix in the first column of each table.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    HEX(COLUMN_NAME) AS column_hex
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'loanportfolio'
  AND ORDINAL_POSITION = 1
ORDER BY TABLE_NAME;

-- =========================================================
-- 2. INITIAL DATA QUALITY CHECKS ON THE SOURCE DATABASE
-- =========================================================

-- Duplicate identifiers.
SELECT `ï»¿branch_id`, COUNT(*) AS occurrences
FROM loanportfolio.branch
GROUP BY `ï»¿branch_id`
HAVING COUNT(*) > 1;

SELECT `ï»¿customer_id`, COUNT(*) AS occurrences
FROM loanportfolio.customer
GROUP BY `ï»¿customer_id`
HAVING COUNT(*) > 1;

SELECT loan_id, COUNT(*) AS occurrences
FROM loanportfolio.loan
GROUP BY loan_id
HAVING COUNT(*) > 1;

SELECT repayment_id, COUNT(*) AS occurrences
FROM loanportfolio.repayment
GROUP BY repayment_id
HAVING COUNT(*) > 1;

-- NULL checks.
SELECT
    SUM(`ï»¿branch_id` IS NULL) AS missing_branch_id,
    SUM(branch_name IS NULL) AS missing_branch_name,
    SUM(state IS NULL) AS missing_state
FROM loanportfolio.branch;

SELECT
    SUM(`ï»¿customer_id` IS NULL) AS missing_customer_id,
    SUM(customer_name IS NULL) AS missing_customer_name,
    SUM(branch_id IS NULL) AS missing_branch_id,
    SUM(state IS NULL) AS missing_state,
    SUM(employment_type IS NULL) AS missing_employment_type,
    SUM(monthly_income_ngn IS NULL) AS missing_monthly_income
FROM loanportfolio.customer;

SELECT
    SUM(loan_id IS NULL) AS missing_loan_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(loan_amount_ngn IS NULL) AS missing_loan_amount,
    SUM(annual_interest_rate_pct IS NULL) AS missing_interest_rate,
    SUM(loan_term_months IS NULL) AS missing_loan_term,
    SUM(disbursement_date IS NULL) AS missing_disbursement_date,
    SUM(due_date IS NULL) AS missing_due_date,
    SUM(loan_status IS NULL) AS missing_loan_status,
    SUM(outstanding_balance_ngn IS NULL) AS missing_outstanding_balance
FROM loanportfolio.loan;

SELECT
    SUM(repayment_id IS NULL) AS missing_repayment_id,
    SUM(loan_id IS NULL) AS missing_loan_id,
    SUM(payment_date IS NULL) AS missing_payment_date,
    SUM(amount_paid_ngn IS NULL) AS missing_amount_paid,
    SUM(payment_method IS NULL) AS missing_payment_method
FROM loanportfolio.repayment;

-- Referential integrity checks before foreign keys are added.
SELECT C.*
FROM loanportfolio.customer AS C
LEFT JOIN loanportfolio.branch AS B
    ON C.branch_id = B.`ï»¿branch_id`
WHERE B.`ï»¿branch_id` IS NULL;

SELECT L.*
FROM loanportfolio.loan AS L
LEFT JOIN loanportfolio.customer AS C
    ON L.customer_id = C.`ï»¿customer_id`
WHERE C.`ï»¿customer_id` IS NULL;

SELECT R.*
FROM loanportfolio.repayment AS R
LEFT JOIN loanportfolio.loan AS L
    ON R.loan_id = L.loan_id
WHERE L.loan_id IS NULL;

-- Financial data checks.
SELECT *
FROM loanportfolio.customer
WHERE monthly_income_ngn < 0;

SELECT *
FROM loanportfolio.loan
WHERE loan_amount_ngn < 0
   OR outstanding_balance_ngn < 0
   OR outstanding_balance_ngn > loan_amount_ngn
   OR annual_interest_rate_pct < 0
   OR loan_term_months <= 0;

SELECT *
FROM loanportfolio.repayment
WHERE amount_paid_ngn <= 0;

-- Loan status and employment category distributions.
SELECT loan_status, COUNT(*) AS total_loans
FROM loanportfolio.loan
GROUP BY loan_status
ORDER BY total_loans DESC;

SELECT employment_type, COUNT(*) AS total_customers
FROM loanportfolio.customer
GROUP BY employment_type
ORDER BY total_customers DESC;

-- Date-format and date-sequence checks on source TEXT columns.
SELECT *
FROM loanportfolio.loan
WHERE STR_TO_DATE(disbursement_date, '%Y-%m-%d') IS NULL
   OR DATE_FORMAT(STR_TO_DATE(disbursement_date, '%Y-%m-%d'), '%Y-%m-%d')
      <> disbursement_date;

SELECT *
FROM loanportfolio.loan
WHERE STR_TO_DATE(due_date, '%Y-%m-%d') IS NULL
   OR DATE_FORMAT(STR_TO_DATE(due_date, '%Y-%m-%d'), '%Y-%m-%d')
      <> due_date;

SELECT *
FROM loanportfolio.repayment
WHERE STR_TO_DATE(payment_date, '%Y-%m-%d') IS NULL
   OR DATE_FORMAT(STR_TO_DATE(payment_date, '%Y-%m-%d'), '%Y-%m-%d')
      <> payment_date;

SELECT *
FROM loanportfolio.loan
WHERE STR_TO_DATE(due_date, '%Y-%m-%d')
    < STR_TO_DATE(disbursement_date, '%Y-%m-%d');

SELECT R.*, L.disbursement_date
FROM loanportfolio.repayment AS R
JOIN loanportfolio.loan AS L
    ON R.loan_id = L.loan_id
WHERE STR_TO_DATE(R.payment_date, '%Y-%m-%d')
    < STR_TO_DATE(L.disbursement_date, '%Y-%m-%d');

-- Individual repayment and outstanding balance checks.
SELECT L.*, R.amount_paid_ngn
FROM loanportfolio.loan AS L
JOIN loanportfolio.repayment AS R
    ON L.loan_id = R.loan_id
WHERE R.amount_paid_ngn > L.loan_amount_ngn
   OR L.outstanding_balance_ngn > L.loan_amount_ngn;

-- 3. CREATE THE WORKING COPY
CREATE DATABASE loanportfolio_clean;
USE loanportfolio_clean;

CREATE TABLE loanportfolio_clean.branch LIKE loanportfolio.branch;
INSERT INTO loanportfolio_clean.branch
SELECT * FROM loanportfolio.branch;

CREATE TABLE loanportfolio_clean.customer LIKE loanportfolio.customer;
INSERT INTO loanportfolio_clean.customer
SELECT * FROM loanportfolio.customer;

CREATE TABLE loanportfolio_clean.loan LIKE loanportfolio.loan;
INSERT INTO loanportfolio_clean.loan
SELECT * FROM loanportfolio.loan;

CREATE TABLE loanportfolio_clean.repayment LIKE loanportfolio.repayment;
INSERT INTO loanportfolio_clean.repayment
SELECT * FROM loanportfolio.repayment;

-- Verify working-copy record counts.
SELECT 'branch' AS table_name, COUNT(*) AS total_records
FROM loanportfolio_clean.branch
UNION ALL
SELECT 'customer', COUNT(*) FROM loanportfolio_clean.customer
UNION ALL
SELECT 'loan', COUNT(*) FROM loanportfolio_clean.loan
UNION ALL
SELECT 'repayment', COUNT(*) FROM loanportfolio_clean.repayment;

-- 4. CLEAN COLUMN NAMES IN THE WORKING COPY
-- Run each rename only once.

ALTER TABLE loanportfolio_clean.branch
RENAME COLUMN `ï»¿branch_id` TO branch_id;

ALTER TABLE loanportfolio_clean.customer
RENAME COLUMN `ï»¿customer_id` TO customer_id;

-- 5. VALIDATE IDENTIFIERS BEFORE ADDING PRIMARY KEYS

SELECT 'branch' AS table_name,
       COUNT(*) AS total_records,
       COUNT(DISTINCT branch_id) AS unique_ids,
       COUNT(branch_id) AS non_null_ids
FROM loanportfolio_clean.branch
UNION ALL
SELECT 'customer', COUNT(*), COUNT(DISTINCT customer_id), COUNT(customer_id)
FROM loanportfolio_clean.customer
UNION ALL
SELECT 'loan', COUNT(*), COUNT(DISTINCT loan_id), COUNT(loan_id)
FROM loanportfolio_clean.loan
UNION ALL
SELECT 'repayment', COUNT(*), COUNT(DISTINCT repayment_id), COUNT(repayment_id)
FROM loanportfolio_clean.repayment;


-- 6. ADD PRIMARY KEY CONSTRAINTS

ALTER TABLE loanportfolio_clean.branch
ADD PRIMARY KEY (branch_id);

ALTER TABLE loanportfolio_clean.customer
ADD PRIMARY KEY (customer_id);

ALTER TABLE loanportfolio_clean.loan
ADD PRIMARY KEY (loan_id);

ALTER TABLE loanportfolio_clean.repayment
ADD PRIMARY KEY (repayment_id);

-- Verify primary keys.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'loanportfolio_clean'
  AND CONSTRAINT_NAME = 'PRIMARY'
ORDER BY TABLE_NAME;

-- 7. CHECK ORPHAN RECORDS BEFORE ADDING FOREIGN KEYS

SELECT C.*
FROM loanportfolio_clean.customer AS C
LEFT JOIN loanportfolio_clean.branch AS B
    ON C.branch_id = B.branch_id
WHERE B.branch_id IS NULL;

SELECT L.*
FROM loanportfolio_clean.loan AS L
LEFT JOIN loanportfolio_clean.customer AS C
    ON L.customer_id = C.customer_id
WHERE C.customer_id IS NULL;

SELECT R.*
FROM loanportfolio_clean.repayment AS R
LEFT JOIN loanportfolio_clean.loan AS L
    ON R.loan_id = L.loan_id
WHERE L.loan_id IS NULL;

-- 8. ADD FOREIGN KEY CONSTRAINTS

ALTER TABLE loanportfolio_clean.customer
ADD CONSTRAINT fk_customer_branch
FOREIGN KEY (branch_id)
REFERENCES loanportfolio_clean.branch(branch_id);

ALTER TABLE loanportfolio_clean.loan
ADD CONSTRAINT fk_loan_customer
FOREIGN KEY (customer_id)
REFERENCES loanportfolio_clean.customer(customer_id);

ALTER TABLE loanportfolio_clean.repayment
ADD CONSTRAINT fk_repayment_loan
FOREIGN KEY (loan_id)
REFERENCES loanportfolio_clean.loan(loan_id);

-- Verify foreign keys.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'loanportfolio_clean'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME;


-- 9. CONVERT TEXT DATE COLUMNS TO DATE

ALTER TABLE loanportfolio_clean.loan
MODIFY COLUMN disbursement_date DATE;

ALTER TABLE loanportfolio_clean.loan
MODIFY COLUMN due_date DATE;

ALTER TABLE loanportfolio_clean.repayment
MODIFY COLUMN payment_date DATE;

-- Verify date data types.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'loanportfolio_clean'
  AND COLUMN_NAME IN ('disbursement_date', 'due_date', 'payment_date')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 10. FINAL VALIDATION

-- Final record counts.
SELECT 'branch' AS table_name, COUNT(*) AS total_records
FROM loanportfolio_clean.branch
UNION ALL
SELECT 'customer', COUNT(*) FROM loanportfolio_clean.customer
UNION ALL
SELECT 'loan', COUNT(*) FROM loanportfolio_clean.loan
UNION ALL
SELECT 'repayment', COUNT(*) FROM loanportfolio_clean.repayment;

-- Confirm all primary and foreign key definitions.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'loanportfolio_clean'
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- Check cumulative repayments do not exceed original loan amounts.
-- A result with no rows indicates no such overpayment was found.
SELECT
    L.loan_id,
    L.loan_amount_ngn,
    SUM(R.amount_paid_ngn) AS total_repaid
FROM loanportfolio_clean.loan AS L
JOIN loanportfolio_clean.repayment AS R
    ON L.loan_id = R.loan_id
GROUP BY L.loan_id, L.loan_amount_ngn
HAVING SUM(R.amount_paid_ngn) > L.loan_amount_ngn;

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'loanportfolio_clean'
ORDER BY TABLE_NAME, COLUMN_NAME;