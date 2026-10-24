
-- BANKING LOAN PORTFOLIO ANALYSIS 


-- SECTION 1: LOAN PORTFOLIO ANALYSIS
-- Business objective: Provide management with a clear understanding of the institution's loan portfolio,
-- its size, composition and outstanding financial exposure.

-- S1-A: Portfolio KPI summary (one row)
-- Q1: overall size and value of the portfolio
-- Q3: how much money remains outstanding
-- Q4: sizes of loans being issued (average, minimum, maximum)
-- Q5: interest rates and repayment terms
-- All of these come from the loan table at the same level (the whole portfolio),

SELECT COUNT(DISTINCT customer_id) AS no_of_customer, COUNT(*) AS no_of_loan,
SUM(loan_amount_ngn) AS total_loan_amount,
SUM(outstanding_balance_ngn) AS total_outstanding_balance,
AVG(loan_amount_ngn) AS avg_loan_amount, MIN(loan_amount_ngn) AS smallest_loan_amount,
MAX(loan_amount_ngn) AS highest_loan_amount,
AVG(annual_interest_rate_pct) AS avg_interest_rate, MIN(annual_interest_rate_pct) AS min_interest_rate,
MAX(annual_interest_rate_pct) AS max_interest_rate,
AVG(loan_term_months) AS avg_loan_term, MIN(loan_term_months) AS min_loan_term,
MAX(loan_term_months) AS max_loan_term
FROM loan;


-- S1-B: Loan distribution and outstanding balance by loan status
-- Q2: how loans are distributed across their different status
-- Q3: how much remains outstanding, by status

WITH loan_report AS (
    SELECT
        loan_status, COUNT(*) AS no_of_loan_by_status, SUM(loan_amount_ngn) AS total_loan_amount,
        SUM(outstanding_balance_ngn) AS total_outstanding_balance
    FROM loan
    GROUP BY loan_status
),
status_summary AS (
    SELECT COUNT(*) AS no_of_loan
    FROM loan
)
SELECT loan_status, no_of_loan_by_status, total_loan_amount, total_outstanding_balance,
    ROUND((no_of_loan_by_status * 100.0 / no_of_loan), 2) AS percentage
FROM loan_report
CROSS JOIN status_summary
ORDER BY total_loan_amount DESC;



-- SECTION 2: CUSTOMER BORROWING BEHAVIOUR

-- S2-A: Customer borrowing KPI summary (one row)
-- How many customers does the bank have?
-- How many have borrowed, and what percentage of the customer base is that?
-- Average number of loans per borrowing customer.
-- How much customers borrow (total, average, minimum, maximum loan amount).
-- Overall loan exposure (total outstanding, and min / max / average outstanding per customer).
WITH customer_report AS (
	SELECT COUNT(DISTINCT customer_id) AS no_of_all_customers
	FROM customer
),
loan_customer_report AS (
	SELECT COUNT(DISTINCT customer_id) AS no_of_borrowed_customers,
	COUNT(*) / COUNT(DISTINCT customer_id) AS avg_no_of_loan_per_cus,
	SUM(loan_amount_ngn) AS total_loan_amount, AVG(loan_amount_ngn) AS avg_loan_amount,
	MIN(loan_amount_ngn) AS min_loan_amount, MAX(loan_amount_ngn) AS max_loan_amount
	FROM loan
),
customer_exposure_base AS (
	SELECT customer_id, SUM(outstanding_balance_ngn) AS customer_exposure
	FROM loan
	GROUP BY customer_id
),
ExposureSummary AS (
	SELECT SUM(customer_exposure) AS total_loan_exposure,
	MIN(customer_exposure) AS min_loan_exposure,
	MAX(customer_exposure) AS max_loan_exposure,
	AVG(customer_exposure) AS avg_loan_exposure
	FROM customer_exposure_base
)
SELECT no_of_all_customers, no_of_borrowed_customers,
ROUND((no_of_borrowed_customers / no_of_all_customers) * 100) AS customer_base_percentage,
avg_no_of_loan_per_cus, total_loan_amount, avg_loan_amount, min_loan_amount, max_loan_amount,
total_loan_exposure, min_loan_exposure, max_loan_exposure, avg_loan_exposure
FROM customer_report CROSS JOIN loan_customer_report CROSS JOIN ExposureSummary;


-- S2-B: Borrowing frequency and customer category
-- How frequently do customers borrow from the bank?
-- Single-loan versus multiple-loan customers
-- Both questions count loans per customer.
WITH customer_summary AS (
	SELECT C.customer_id, COUNT(L.loan_id) AS borrowing_frequency
	FROM customer AS C LEFT JOIN loan AS L
	ON C.customer_id = L.customer_id
	GROUP BY C.customer_id
)
SELECT borrowing_frequency,
	CASE
		WHEN  borrowing_frequency = 1 THEN 'Single-loan Customer'
		WHEN  borrowing_frequency > 1 THEN 'Multiple-loan Customer'
		ELSE 'Never Borrowed'
	END AS CustomerCategory,
	COUNT(customer_id) AS no_of_customers
FROM customer_summary
GROUP BY borrowing_frequency
ORDER BY borrowing_frequency;


-- S2-C: Borrowing activity by state and employment type
-- How is borrowing activity distributed across states?
-- How is borrowing activity distributed across employment types?

SELECT state, employment_type, COUNT(L.loan_id) AS no_of_loan, SUM(loan_amount_ngn) AS total_loan_amount
FROM customer AS C INNER JOIN loan AS L
ON C.customer_id = L.customer_id
GROUP BY state, employment_type
ORDER BY state, total_loan_amount DESC;


-- S2-D: Customer-level loan and exposure table
-- How much does each customer borrow, and how much does each customer still owe?
-- Top 10 customers: filter customer_rank <= 10 in Excel.

SELECT customer_id, COUNT(*) AS no_of_loan,
       SUM(loan_amount_ngn) AS total_loan_amount,
       SUM(outstanding_balance_ngn) AS total_outstanding_balance,
       ROW_NUMBER() OVER(
		ORDER BY SUM(loan_amount_ngn) DESC, customer_id
       ) AS customer_rank
FROM loan
GROUP BY customer_id
ORDER BY customer_rank;


-- S2-E: Customer concentration summary (one row)
-- Customers who account for a substantial proportion of the institution's lending activities.
-- This is your concentration query unchanged.
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


-- S2-F: Customers by outstanding balance range
-- How are customers distributed across different outstanding balance ranges?

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


-- S2-G: Loan amount frequency
SELECT
    loan_amount_ngn,
    COUNT(DISTINCT customer_id) AS no_of_unique_customer,
    COUNT(customer_id) AS loan_occurrences
FROM
    loan
GROUP BY loan_amount_ngn
ORDER BY loan_occurrences DESC;


-- SECTION 3: LOAN REPAYMENT PERFORMANCE ANALYSIS 

-- S3-A: Overall repayment collections
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


-- S3-B: Repayment collections by year and month
-- Yearly analysis, monthly analysis and monthly trends across years.
-- This is your year-and-month query. Yearly totals = add the months of a year in Excel;
-- monthly (seasonal) totals = add the same month across years.

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


-- S3-C: Repayment coverage by loan status  
-- Loans without repayments: how many loans have received no repayments, and what is their total original loan value?
-- How much money has the bank collected against loans under each current loan status?
-- Both questions look at loans grouped by loan status, so they share one result.
WITH repayment_per_loan AS (
    SELECT loan_id, SUM(amount_paid_ngn) AS total_paid
    FROM repayment
    GROUP BY loan_id
)
SELECT L.loan_status,
    COUNT(L.loan_id) AS no_of_loan,
    SUM(CASE WHEN RL.loan_id IS NULL THEN 1 ELSE 0 END) AS loans_without_repayment,
    SUM(CASE WHEN RL.loan_id IS NULL THEN L.loan_amount_ngn ELSE 0 END) AS loan_value_without_repayment,
    SUM(L.loan_amount_ngn) AS total_loan_amount,
    COALESCE(SUM(RL.total_paid), 0) AS total_amount_paid
FROM loan AS L
LEFT JOIN repayment_per_loan AS RL
ON L.loan_id = RL.loan_id
GROUP BY L.loan_status
ORDER BY total_amount_paid DESC;


--  BRANCH ANALYSIS 

-- Branch performance (branch level, with state)
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
    b.state,
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

-- Area 4: Credit Risk and Default Analysis
-- 1. How many loans have defaulted, and what is their total original loan value and total outstanding balance?
SELECT COUNT(loan_id) AS number_of_defaulted_loans, 
SUM(loan_amount_ngn) AS total_loan_value, 
SUM(outstanding_balance_ngn) AS total_outstanding_value
FROM loan
WHERE loan_status = 'Defaulted';

--  How are defaulted loans distributed across different loan-term periods? AND
--  Which loan-term categories have the highest number and proportion of defaults?
WITH loan_term_summary AS (
    SELECT loan_term_months, COUNT(*) AS total_loans,
        SUM(CASE
            WHEN loan_status = 'Defaulted' THEN 1
            ELSE 0
        END) AS defaulted_loan_count
    FROM loan
    GROUP BY loan_term_months
),
default_total AS (
    SELECT SUM(defaulted_loan_count) AS total_defaults
    FROM loan_term_summary
)
SELECT
    L.loan_term_months,
    L.total_loans,
    L.defaulted_loan_count,
    ROUND(L.defaulted_loan_count * 100.0 / L.total_loans, 2) AS default_rate_percentage,
    ROUND(L.defaulted_loan_count * 100.0 / D.total_defaults, 2) AS share_of_all_defaults
FROM loan_term_summary AS L
CROSS JOIN default_total AS D
ORDER BY default_rate_percentage DESC;

-- What is the monthly income distribution of customers with defaulted loans?
SELECT C.monthly_income_ngn, COUNT(DISTINCT L.customer_id) AS customer_count
FROM customer AS C INNER JOIN loan AS L
ON C.customer_id = L.customer_id
WHERE L.loan_status = 'Defaulted'
GROUP BY  C.monthly_income_ngn
ORDER BY customer_count DESC;

-- Which customers have relatively high borrowing amounts compared with their monthly income?
WITH customer_borrowing AS (
    SELECT
        C.customer_id,
        MAX(C.monthly_income_ngn) AS monthly_income,
        SUM(L.loan_amount_ngn) AS total_borrowed
    FROM customer AS C
    INNER JOIN loan AS L
        ON C.customer_id = L.customer_id
    GROUP BY C.customer_id
),
ratio_summary AS (
    SELECT
        customer_id,
        monthly_income,
        total_borrowed,
        ROUND(total_borrowed / NULLIF(monthly_income, 0), 2)
            AS borrowing_income_ratio
    FROM customer_borrowing
)
SELECT *
FROM ratio_summary
WHERE borrowing_income_ratio > 1
AND EXISTS (
    SELECT 1
    FROM loan AS L2
    WHERE L2.loan_status = 'Defaulted'
      AND L2.customer_id = ratio_summary.customer_id
)
ORDER BY borrowing_income_ratio DESC;

-- Employment Type and Loan Performance

-- How are the bank's loans distributed across different employment categories?
-- How much has been disbursed and collected across each employment category?
WITH repayment_summary AS (
    SELECT
        loan_id,
        SUM(amount_paid_ngn) AS total_repaid
    FROM repayment
    GROUP BY loan_id
)
SELECT
    C.employment_type, COUNT(L.loan_id) AS total_loans,
    SUM(L.loan_amount_ngn) AS total_disbursed,
    SUM(COALESCE(R.total_repaid, 0)) AS total_repaid
FROM customer AS C
INNER JOIN loan AS L
    ON C.customer_id = L.customer_id
LEFT JOIN repayment_summary AS R
    ON L.loan_id = R.loan_id
GROUP BY C.employment_type
ORDER BY total_loans DESC;

-- Which employment categories have the highest and lowest numbers of defaulted loans?
-- Which employment categories have the highest and lowest default rates?
SELECT
    C.employment_type,
    COUNT(L.loan_id) AS total_loans,
    SUM(CASE
        WHEN L.loan_status = 'Defaulted' THEN 1
        ELSE 0
    END) AS defaulted_loans,
    ROUND(
        SUM(CASE
            WHEN L.loan_status = 'Defaulted' THEN 1
            ELSE 0
        END) * 100.0 / COUNT(L.loan_id), 2
    ) AS default_rate
FROM customer AS C
INNER JOIN loan AS L
    ON C.customer_id = L.customer_id
GROUP BY C.employment_type
ORDER BY default_rate DESC;