-- Loan portfolio analysis 
-- Business objective: Provide management with a clear understanding of the institution's loan portfolio, 
-- its size, composition and outstanding financial exposure.-- 

-- Q1: Management wants to understand the overall size and value of the loan portfolio.
SELECT COUNT(DISTINCT customer_id) AS no_of_customer, COUNT(*) AS no_of_loan, SUM(loan_amount_ngn) AS total_loan_amount
FROM loan; 

-- Q2.	Management wants to know how loans are distributed across their different status;
WITH loan_report AS (
    SELECT 
        loan_status, COUNT(*) AS no_of_loan_by_status, SUM(loan_amount_ngn) AS total_loan_amount
    FROM loan
    GROUP BY loan_status
),
status_summary AS (
    SELECT COUNT(*) AS no_of_loan
    FROM loan
)
SELECT loan_status, no_of_loan_by_status, total_loan_amount, 
    ROUND((no_of_loan_by_status * 100.0 / no_of_loan), 2) AS percentage
FROM loan_report 
CROSS JOIN status_summary
ORDER BY total_loan_amount DESC;

-- Q3.	Management wants to understand how much money remains outstanding on its loans.
SELECT loan_status, SUM(outstanding_balance_ngn) AS total_outstanding_balance
FROM loan
GROUP BY loan_status
ORDER BY total_outstanding_balance DESC; 

-- Q4.	Management wants to understand the sizes of loans being issued to customers. 
-- loan size means focusing on average loan amount, max and minimum loan amount.
SELECT AVG(loan_amount_ngn) AS  avg_loan_amount, MIN(loan_amount_ngn) AS smalles_loan_amount, 
MAX(loan_amount_ngn) AS highest_loan_amount
FROM Loan;

-- Q5.	Management wants to understand the interest rates and repayment terms attached to the institution's loans.
WITH interest_rate_report AS (
	SELECT AVG(annual_interest_rate_pct) AS  avg_interest_rate, MIN(annual_interest_rate_pct) AS min_interest_rate, 
	MAX(annual_interest_rate_pct) AS max_interest_rate
	FROM loan
), repayment_terms AS (
	SELECT AVG(loan_term_months) AS  avg_loan_term, MIN(loan_term_months) AS min_loan_term, 
	MAX(loan_term_months) AS max_loan_term
	FROM loan)
SELECT *
FROM interest_rate_report CROSS JOIN repayment_terms;


-- CUSTOMER BORROWING BEHAVIOUR

 