CREATE DATABASE PROJECT_FINAL;
UPDATE customers SET GENDER = NULL WHERE GENDER = '';
UPDATE customers SET AGE = NULL WHERE AGE = '';
ALTER TABLE customers MODIFY AGE INT NULL;
SELECT * FROM customers;

CREATE TABLE  TRANSACTION
(data_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

lOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTION_FINAL.CSV'
INTO TABLE TRANSACTION
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'SECURE_FILE_PRIV';


--                              Финальный проект
--                                Блок SQL

-- 1) Cписок клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков 
-- за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц,
-- количество всех операций по клиенту за период;

SELECT
    t.ID_client,
    COUNT(DISTINCT DATE_FORMAT(t.data_new, '%Y-%m')) AS active_months,
    COUNT(*) AS total_operations,
    ROUND(SUM(t.Sum_payment) / COUNT(*), 2) AS avg_check,
    ROUND(SUM(t.Sum_payment) / 12, 2) AS avg_monthly_payment
FROM transactions t
WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY t.ID_client
HAVING active_months = 12;


-- 2) информацию в разрезе месяцев:
--    a) средняя сумма чека в месяц;
--    b) среднее количество операций в месяц;
--    c) среднее количество клиентов, которые совершали операции;
--    d) долю от общего количества операций за год и долю в месяц от общей суммы операций;
--    e) вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

 
 -- 🔹 a) . Средняя сумма чека в месяц.
SELECT 
    DATE_FORMAT(data_new, '%Y-%m') AS month,
    AVG(Sum_payment) AS avg_check
FROM transactions
GROUP BY month
ORDER BY month;

-- 🔹 b). Среднее количество операций в месяц.
SELECT 
    DATE_FORMAT(data_new, '%Y-%m') AS month,
    COUNT(*) AS total_operations
FROM transactions
GROUP BY month
ORDER BY month;

-- 🔹 c). Среднее количество клиентов, совершивших операции в месяц.
SELECT 
    DATE_FORMAT(data_new, '%Y-%m') AS month,
    COUNT(DISTINCT Id_client) AS active_clients
FROM transactions
GROUP BY month
ORDER BY month;

-- 🔹 d). Доля операций и суммы в месяц по сравнению с годом.
WITH monthly_data AS (
    SELECT 
        DATE_FORMAT(data_new, '%Y-%m') AS month,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum
    FROM transactions
    GROUP BY month
),
yearly_data AS (
    SELECT 
        COUNT(*) AS year_operations,
        SUM(Sum_payment) AS year_sum
    FROM transactions
)
SELECT 
    m.month,
    m.operations,
    m.total_sum,
    ROUND(m.operations / y.year_operations * 100, 2) AS percent_operations,
    ROUND(m.total_sum / y.year_sum * 100, 2) AS percent_sum
FROM monthly_data m, yearly_data y
ORDER BY m.month;

-- 🔹 е). % M/F/NA по месяцам + доля затрат.
SELECT 
    DATE_FORMAT(t.data_new, '%Y-%m') AS month,
    c.Gender,
    COUNT(DISTINCT t.Id_client) AS client_count,
    ROUND(SUM(t.Sum_payment), 2) AS total_spent,
    ROUND(SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.data_new, '%Y-%m')) * 100, 2) AS percent_spent
FROM transactions t
JOIN customers c ON t.Id_client = c.Id_client
GROUP BY month, c.Gender
ORDER BY month, c.Gender;

-- 3) возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
-- с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

SELECT
    CASE
        WHEN Age IS NULL THEN 'Unknown'
        WHEN Age BETWEEN 0 AND 9 THEN '0-9'
        WHEN Age BETWEEN 10 AND 19 THEN '10-19'
        WHEN Age BETWEEN 20 AND 29 THEN '20-29'
        WHEN Age BETWEEN 30 AND 39 THEN '30-39'
        WHEN Age BETWEEN 40 AND 49 THEN '40-49'
        WHEN Age BETWEEN 50 AND 59 THEN '50-59'
        WHEN Age BETWEEN 60 AND 69 THEN '60-69'
        WHEN Age >= 70 THEN '70+'
    END AS age_group,
    COUNT(*) AS total_operations,
    SUM(t.Sum_payment) AS total_payment
FROM transactions t
JOIN customers c ON t.ID_client = c.Id_client
WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY age_group
ORDER BY age_group;


WITH age_stats AS (
    SELECT
        CONCAT(YEAR(t.data_new), '-Q', QUARTER(t.data_new)) AS quarter,
        CASE
            WHEN c.Age IS NULL THEN 'Unknown'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age >= 70 THEN '70+'
        END AS age_group,
        ROUND(AVG(t.Sum_payment), 2) AS avg_payment,
        COUNT(*) AS ops_count
    FROM transactions t
    JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY quarter, age_group
)
SELECT
    a.quarter,
    a.age_group,
    a.avg_payment,
    a.ops_count,
    ROUND(a.ops_count * 100.0 / total.total_ops, 2) AS percent_ops_share
FROM age_stats a
JOIN (
    SELECT
        CONCAT(YEAR(data_new), '-Q', QUARTER(data_new)) AS quarter,
        COUNT(*) AS total_ops
    FROM transactions
    WHERE data_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY quarter
) total ON a.quarter = total.quarter
ORDER BY a.quarter, a.age_group;
