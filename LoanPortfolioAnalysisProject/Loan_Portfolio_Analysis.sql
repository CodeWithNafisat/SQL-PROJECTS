USE LoanPortfolio;

-- TO CONFIRM DATABASE AND TABLE STRUCTURE
SHOW TABLES;
-- To inspect columns names and datatypes
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

-- Verify database relationship
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'loanportfolio'; 

--  Verify record count
SELECT COUNT(*) AS no_of_branch
FROM branch;

SELECT COUNT(*) AS no_of_customers
FROM customer;

SELECT COUNT(*) AS no_of_loan
FROM loan;

SELECT COUNT(*) AS no_of_repayment
FROM repayment;

-- Verify the encoding artefact from each table
SELECT TABLE_NAME, COLUMN_NAME, HEX(COLUMN_NAME) AS COLUMN_HEX
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'loanportfolio'
AND ORDINAL_POSITION = 1;

-- Data quality assessment
-- first check for duplicates
SELECT `ï»¿branch_id`, COUNT(*) AS occurrences
FROM branch
GROUP BY `ï»¿branch_id`
HAVING COUNT(*) > 1;  

SELECT `ï»¿customer_id`, COUNT(*) AS occurrences
FROM customer
GROUP BY `ï»¿customer_id`
HAVING COUNT(*) > 1;

SELECT `ï»¿loan_id`, COUNT(*) AS occurrences
FROM loan
GROUP BY `ï»¿loan_id`
HAVING COUNT(*) > 1; 

SELECT `ï»¿repayment_id`, COUNT(*) AS occurrences
FROM repayment
GROUP BY `ï»¿repayment_id`
HAVING COUNT(*) > 1;     

-- check for missing values
 SELECT
    SUM(`ï»¿branch_id` IS NULL) AS missing_branch_id,
    SUM(branch_name IS NULL) AS missing_branch_name,
    SUM(state IS NULL) AS missing_state
FROM branch;

SELECT
    SUM(`ï»¿customer_id` IS NULL) AS missing_customer_id,
    SUM(customer_name IS NULL) AS missing_customer_name,
    SUM(branch_id IS NULL) AS missing_branch_id,
    SUM(state IS NULL) AS missing_state,
    SUM(employment_type IS NULL) AS missing_employment_type,
    SUM(monthly_income_ngn IS NULL) AS missing_monthly_income
FROM customer;

SELECT
    SUM(`ï»¿loan_id` IS NULL) AS missing_loan_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(loan_amount_ngn IS NULL) AS missing_loan_amount,
    SUM(annual_interest_rate_pct IS NULL) AS missing_interest_rate,
    SUM(loan_term_months IS NULL) AS missing_loan_term,
    SUM(disbursement_date IS NULL) AS missing_disbursement_date,
    SUM(due_date IS NULL) AS missing_due_date,
    SUM(loan_status IS NULL) AS missing_loan_status,
    SUM(outstanding_balance_ngn IS NULL) AS missing_outstanding_balance
FROM loan;

SELECT
    SUM(`ï»¿repayment_id` IS NULL) AS missing_repayment_id,
    SUM(loan_id IS NULL) AS missing_loan_id,
    SUM(payment_date IS NULL) AS missing_payment_date,
    SUM(amount_paid_ngn IS NULL) AS missing_amount_paid,
    SUM(payment_method IS NULL) AS missing_payment_method
FROM repayment;

-- Verify relationship integrity
-- Customer with no matching branch 
SELECT C.*
FROM customer AS C LEFT JOIN branch AS B
ON C.branch_id =  B.`ï»¿branch_id` 
WHERE B.`ï»¿branch_id` IS NULL;

-- Loan without matching customer
SELECT L.*
FROM loan AS L LEFT JOIN customer as C
ON L.customer_id =  C.`ï»¿customer_id` 
WHERE C.`ï»¿customer_id` IS NULL;

-- Repayment without loan
SELECT R.*
FROM repayment R
LEFT JOIN loan L
    ON R.loan_id = L.`ï»¿loan_id`
WHERE L.`ï»¿loan_id` IS NULL; 

-- Investigate financial data quality
SELECT monthly_income_ngn
FROM customer 
WHERE monthly_income_ngn < 0; 

SELECT *
FROM loan
WHERE loan_amount_ngn <= 0
   OR outstanding_balance_ngn < 0
   OR outstanding_balance_ngn > loan_amount_ngn
   OR annual_interest_rate_pct < 0
   OR loan_term_months <= 0;
   
SELECT amount_paid_ngn
FROM repayment
WHERE amount_paid_ngn < 0;

-- Loan status distribution
SELECT loan_status, COUNT(*) AS total_loan
FROM loan
GROUP BY loan_status
ORDER BY total_loan DESC;

-- Employment tyoe distribtution 
SELECT employment_type, COUNT(*) AS total_employment_type
FROM customer
GROUP BY employment_type
ORDER BY total_employment_type DESC;

--  Checking invalid disbursement dates and due dates 
SELECT * 
FROM loan
WHERE STR_TO_DATE(disbursement_date, '%Y-%m-%d') IS NULL
	OR
DATE_FORMAT(STR_TO_DATE(disbursement_date, '%Y-%m-%d'), '%Y-%m-%d') <> disbursement_date;

SELECT * 
FROM loan
WHERE STR_TO_DATE(due_date, '%Y-%m-%d') IS NULL
	OR
DATE_FORMAT(STR_TO_DATE(due_date, '%Y-%m-%d'), '%Y-%m-%d') <> due_date;

-- Check invalid repayment dates 
SELECT * 
FROM repayment
WHERE STR_TO_DATE(payment_date, '%Y-%m-%d') IS NULL
	OR
DATE_FORMAT(STR_TO_DATE(payment_date, '%Y-%m-%d'), '%Y-%m-%d') <> payment_date;

-- Verify that NO due date comes before
SELECT * 
FROM loan
WHERE STR_TO_DATE(due_date, '%Y-%m-%d')
    < STR_TO_DATE(disbursement_date, '%Y-%m-%d');







