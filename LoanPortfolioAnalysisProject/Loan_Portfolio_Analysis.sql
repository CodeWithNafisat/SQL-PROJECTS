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
SELECT SUM(outstanding_balance_ngn) AS total_outstanding_balance
FROM loan;

SELECT loan_status, SUM(outstanding_balance_ngn) AS total_outstanding_balance
FROM loan
GROUP BY loan_status
ORDER BY total_outstanding_balance DESC;

-- Q4.	Management wants to understand the sizes of loans being issued to customers.
-- loan size means focusing on average loan amount, max and minimum loan amount.
SELECT AVG(loan_amount_ngn) AS  avg_loan_amount, MIN(loan_amount_ngn) AS smallest_loan_amount,
MAX(loan_amount_ngn) AS highest_loan_amount
FROM loan;

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

-- Q1.	Management wants to understand the overall borrowing activity of its customer base.
-- How many customers does the bank have?
-- How many customers have borrowed from the bank, and what percentage of the customer base do they represent?
WITH customer_report AS (
	SELECT COUNT(DISTINCT customer_id) AS no_of_all_customers
	FROM customer
),loan_customer_report AS (
	SELECT COUNT(DISTINCT customer_id) AS no_of_borrowed_customers
	FROM loan
)
SELECT no_of_all_customers, no_of_borrowed_customers,
ROUND((no_of_borrowed_customers / no_of_all_customers) * 100) AS customer_base_percentage
FROM customer_report CROSS JOIN loan_customer_report;

-- How frequently do customers borrow from the bank?
SELECT borrowing_frequency, COUNT(borrowing_frequency) AS no_of_customers
FROM (
	SELECT customer_id, COUNT(*) AS borrowing_frequency
	FROM loan
	GROUP BY customer_id
)AS summary
GROUP BY borrowing_frequency
ORDER BY no_of_customers DESC;

-- What is the average number of loans per borrowing customer?
SELECT AVG(no_of_loan_customer) AS avg_no_of_loan_per_cus
FROM (
	SELECT customer_id, COUNT(*) no_of_loan_customer
    FROM loan
    GROUP BY customer_id
) AS loan_count_per_customer;

-- How is borrowing activity distributed across states?
SELECT state, COUNT(L.loan_id) AS no_of_loan, SUM(loan_amount_ngn) AS total_loan_amount_per_state
FROM customer AS C INNER JOIN loan AS L
ON C.customer_id = L.customer_id
GROUP BY state
ORDER BY total_loan_amount_per_state DESC;

-- How is borrowing activity distributed across employment types?
SELECT employment_type, COUNT(L.loan_id) AS no_of_loan, SUM(loan_amount_ngn) AS loan_amount_per_employment_type
FROM customer AS C INNER JOIN loan AS L
ON C.customer_id = L.customer_id
GROUP BY employment_type
ORDER BY loan_amount_per_employment_type DESC;


-- Q2. Single-loan versus multiple-loan customers
WITH customer_summary AS (
		SELECT C.customer_id, COUNT(L.loan_id) AS no_of_loan,
		CASE
			WHEN  COUNT(L.loan_id) = 1 THEN 'Single-loan Customer'
			WHEN  COUNT(L.loan_id) > 1 THEN 'Multiple-loan Customer'
			ELSE 'Never Borrowed'
		END AS CustomerCategory
	FROM customer AS C LEFT JOIN loan AS L
    ON C.customer_id = L.customer_id
	GROUP BY C.customer_id
)
SELECT CustomerCategory, COUNT(CustomerCategory) AS no_of_cus_per_category
FROM customer_summary
GROUP BY CustomerCategory;

-- Management wants to understand how much customers borrow from the institution.
SELECT SUM(loan_amount_ngn) AS total_loan_amount,  AVG(loan_amount_ngn) AS avg_loan_amount,
MIN(loan_amount_ngn) AS min_loan_amount, MAX(loan_amount_ngn) AS max_loan_amount
FROM loan;

SELECT customer_id, COUNT(*) AS no_of_loan, SUM(loan_amount_ngn) AS total_loan_amount
FROM loan
GROUP  BY customer_id
ORDER BY total_loan_amount DESC;

SELECT
    loan_amount_ngn,
    COUNT(DISTINCT customer_id) AS no_of_unique_customer,
    COUNT(customer_id) AS loan_occurrences
FROM
    loan
GROUP BY loan_amount_ngn
ORDER BY loan_occurrences DESC;


--  Management wants to identify customers who account for a substantial proportion of the institution's lending activities.
SELECT customer_id, COUNT(*) AS no_of_loan,
       SUM(loan_amount_ngn) AS total_amount,
       ROW_NUMBER() OVER(
		ORDER BY SUM(loan_amount_ngn) DESC, customer_id
       ) AS customer_rank
FROM loan
GROUP BY customer_id
ORDER BY customer_rank
LIMIT 10;

SELECT SUM(total_amount) AS total_sum
FROM (
	SELECT customer_id, COUNT(*) AS no_of_loan,
		   SUM(loan_amount_ngn) AS total_amount
	FROM loan
	GROUP BY customer_id
	ORDER BY total_amount DESC, customer_id
    LIMIT 10
) AS summary;

WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(*) AS no_of_loan,
        SUM(loan_amount_ngn) AS total_amount
    FROM loan
    GROUP BY customer_id
),

ranked_customers AS (
    SELECT *,
        ROW_NUMBER() OVER(
            ORDER BY total_amount DESC, customer_id
        ) AS customer_rank,
        SUM(total_amount) OVER() AS portfolio_total
    FROM customer_summary
)

SELECT
    MAX(portfolio_total) AS total_portfolio,

    SUM(CASE WHEN customer_rank <= 10
        THEN total_amount ELSE 0 END) AS top_10_amount,

    ROUND(
        SUM(CASE WHEN customer_rank <= 10
            THEN total_amount ELSE 0 END)
        / MAX(portfolio_total) * 100, 2
    ) AS top_10_percentage,

    SUM(CASE WHEN customer_rank <= 20
        THEN total_amount ELSE 0 END) AS top_20_amount,

    ROUND(
        SUM(CASE WHEN customer_rank <= 20
            THEN total_amount ELSE 0 END)
        / MAX(portfolio_total) * 100, 2
    ) AS top_20_percentage,

	SUM(CASE WHEN customer_rank <= 50
			THEN total_amount ELSE 0 END) AS top_50_amount,

    ROUND(
        SUM(CASE WHEN customer_rank <= 50
            THEN total_amount ELSE 0 END)
        / MAX(portfolio_total) * 100, 2
    ) AS top_50_percentage

FROM ranked_customers;

-- Q5. Management wants to understand how much of the institution's loan exposure is associated with individual customers.
WITH customer_exposure_base AS (
	SELECT customer_id, SUM(outstanding_balance_ngn) AS customer_exposure
    FROM loan
    GROUP BY customer_id
),
OverallCustomerExposure AS (
	SELECT SUM(customer_exposure) AS total_loan_exposure
    FROM customer_exposure_base
),
ExposureSummary AS (
	SELECT MIN(customer_exposure) AS min_loan_exposure,
    MAX(customer_exposure) AS max_loan_exposure,
    AVG(customer_exposure) AS avg_loan_exposure
    FROM customer_exposure_base
)
SELECT *
FROM OverallCustomerExposure CROSS JOIN ExposureSummary;

-- Total outstanding balance owned by each customer
SELECT customer_id, SUM(outstanding_balance_ngn) total_loan_exposure
FROM loan
GROUP BY customer_id
ORDER BY SUM(outstanding_balance_ngn) DESC;

--  How are customers distributed across different outstanding balance ranges? How many customers fall within each range?
WITH customer_balance AS (
    SELECT
        customer_id,
        SUM(outstanding_balance_ngn) AS total_outstanding_balance
    FROM loan
    GROUP BY customer_id
),

customer_exposure AS (
    SELECT
        customer_id,
        total_outstanding_balance,
        CASE
            WHEN total_outstanding_balance <= 100000 THEN 'Very Low'
            WHEN total_outstanding_balance <= 300000 THEN 'Low'
            WHEN total_outstanding_balance <= 600000 THEN 'Moderate'
            WHEN total_outstanding_balance <= 1000000 THEN 'High'
            ELSE 'Very High'
        END AS exposure_category
    FROM customer_balance
),

exposure_distribution AS (
    SELECT
        exposure_category,
        COUNT(*) AS customer_count,
        SUM(total_outstanding_balance) AS total_outstanding_balance
    FROM customer_exposure
    GROUP BY exposure_category
)

SELECT
    exposure_category,
    customer_count,
    ROUND(
        customer_count * 100.0 / SUM(customer_count) OVER (),
        2
    ) AS customer_percentage,
    total_outstanding_balance
FROM exposure_distribution;


-- Loan Repayment Performance Analysis
--  Overall repayment collections
WITH repayment_summary AS (
    SELECT
        COUNT(repayment_id) AS total_repayment_transactions,
        SUM(amount_paid_ngn) AS total_repayment_amount,
        AVG(amount_paid_ngn) AS average_repayment_amount
    FROM repayment
),
loan_summary AS (
    SELECT
        SUM(loan_amount_ngn) AS total_disbursed_amount
    FROM loan
)
SELECT
    total_repayment_transactions, total_disbursed_amount, total_repayment_amount,
    average_repayment_amount,
    (total_repayment_amount * 100.0 / total_disbursed_amount) AS repayment_collection_percentage
FROM repayment_summary
CROSS JOIN loan_summary;

-- Q2. Repayment collections over time
-- yearly repayment analysis
SELECT
    YEAR(payment_date) AS repayment_year,
    SUM(amount_paid_ngn) AS total_repayment_amount,
    AVG(amount_paid_ngn) AS average_repayment_amount,
    COUNT(repayment_id) AS total_repayment_transactions
FROM repayment
GROUP BY YEAR(payment_date)
ORDER BY repayment_year ASC;

-- Monthly repayment analysis
SELECT
    MONTHNAME(payment_date) AS repayment_month,
    SUM(amount_paid_ngn) AS total_repayment_amount,
    AVG(amount_paid_ngn) AS average_repayment_amount,
    COUNT(repayment_id) AS total_repayment_transactions
FROM repayment
GROUP BY MONTHNAME(payment_date)
ORDER BY MONTH(MIN(payment_date)) ASC;

-- Monthly repayment trends across different years
SELECT
    YEAR(payment_date) AS repayment_year,
    MONTH(payment_date) AS repayment_month_number,
    MONTHNAME(payment_date) AS repayment_month,
    SUM(amount_paid_ngn) AS total_repayment_amount,
    AVG(amount_paid_ngn) AS average_repayment_amount,
    COUNT(repayment_id) AS total_repayment_transactions
FROM repayment
GROUP BY
    YEAR(payment_date),
    MONTH(payment_date),
    MONTHNAME(payment_date)
ORDER BY
    repayment_year ASC,
    repayment_month_number ASC;


-- Loans without repayments
-- How many loans have received no repayments, and what is their total original loan value? 
SELECT
    COUNT(L.loan_id) AS loans_without_repayment,
    SUM(L.loan_amount_ngn) AS total_loan_value
FROM loan L
LEFT JOIN repayment R
    ON L.loan_id = R.loan_id
WHERE R.loan_id IS NULL;

-- How much money has the bank collected against loans under each current loan status
SELECT L.loan_status, SUM(R.amount_paid_ngn) AS total_amount_paid
FROM loan AS L 
INNER JOIN repayment AS R
ON L.loan_id = R.loan_id
GROUP BY loan_status
ORDER BY total_amount_paid DESC;

-- How much money has the bank collected against loans under each branch and what is the total loan amount
SELECT L.loan_status, SUM(R.amount_paid_ngn) AS total_amount_paid
FROM loan AS L 
INNER JOIN repayment AS R
ON L.loan_id = R.loan_id
GROUP BY loan_status
ORDER BY total_amount_paid DESC;

-- BRANCH ANALYSIS 
WITH customer_count AS (
    SELECT
        branch_id,
        COUNT(customer_id) AS total_customers
    FROM customer
    GROUP BY branch_id
),
loan_disbursement AS (
    SELECT
        c.branch_id,
        SUM(l.loan_amount_ngn) AS total_disbursed
    FROM customer c
    JOIN loan l
        ON c.customer_id = l.customer_id
    GROUP BY c.branch_id
),
repayment_collection AS (
    SELECT
        c.branch_id,
        SUM(r.amount_paid_ngn) AS total_repaid
    FROM customer c
    JOIN loan l
        ON c.customer_id = l.customer_id
    JOIN repayment r
        ON l.loan_id = r.loan_id
    GROUP BY c.branch_id
)
SELECT
    b.branch_name,
    COALESCE(cc.total_customers, 0) AS total_customers,
    COALESCE(ld.total_disbursed, 0) AS total_disbursed,
    COALESCE(rc.total_repaid, 0) AS total_repaid
FROM branch b
LEFT JOIN customer_count cc
    ON b.branch_id = cc.branch_id
LEFT JOIN loan_disbursement ld
    ON b.branch_id = ld.branch_id
LEFT JOIN repayment_collection rc
    ON b.branch_id = rc.branch_id
ORDER BY total_disbursed DESC;


WITH customer_count AS (
    SELECT
        b.state,
        COUNT(c.customer_id) AS total_customers
    FROM branch b
    JOIN customer c
        ON b.branch_id = c.branch_id
    GROUP BY b.state
),

loan_disbursement AS (
    SELECT
        b.state,
        SUM(l.loan_amount_ngn) AS total_disbursed
    FROM branch b
    JOIN customer c
        ON b.branch_id = c.branch_id
    JOIN loan l
        ON c.customer_id = l.customer_id
    GROUP BY b.state
),

repayment_collection AS (
    SELECT
        b.state,
        SUM(r.amount_paid_ngn) AS total_repaid
    FROM branch b
    JOIN customer c
        ON b.branch_id = c.branch_id
    JOIN loan l
        ON c.customer_id = l.customer_id
    JOIN repayment r
        ON l.loan_id = r.loan_id
    GROUP BY b.state
)

SELECT
    b.state,
    COALESCE(cc.total_customers, 0) AS total_customers,
    COALESCE(ld.total_disbursed, 0) AS total_disbursed,
    COALESCE(rc.total_repaid, 0) AS total_repaid
FROM branch b
LEFT JOIN customer_count cc
    ON b.state = cc.state
LEFT JOIN loan_disbursement ld
    ON b.state = ld.state
LEFT JOIN repayment_collection rc
    ON b.state = rc.state
GROUP BY
    b.state,
    cc.total_customers,
    ld.total_disbursed,
    rc.total_repaid
ORDER BY total_disbursed DESC;