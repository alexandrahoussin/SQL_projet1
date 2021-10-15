-- RH
CREATE VIEW KPI_HR AS(
WITH employee_rank AS(
    SELECT
        YEAR(payments.paymentDate) AS payment_year,
        MONTH(payments.paymentDate) AS payment_month,
        ROW_NUMBER() OVER(
            PARTITION BY YEAR(payments.paymentDate),
            MONTH(payments.paymentDate)
            order by
                SUM(amount) DESC
        ) as row_num,
        employees.lastName,
        employees.firstName,
        SUM(payments.amount) as turnover
    FROM
        employees
        JOIN customers ON employees.employeeNumber = customers.salesRepEmployeeNumber
        JOIN payments ON customers.customerNumber = payments.customerNumber
    WHERE
        (
            payments.paymentDate > curdate() - interval (dayofmonth(curdate()) - 1) day - interval 6 month
        )
        AND (MONTH(payments.paymentDate) != MONTH(curdate()))
    GROUP by
        YEAR(payments.paymentDate),
        MONTH(payments.paymentDate),
        employees.employeeNumber
)
SELECT
    STR_TO_DATE(
        CONCAT(
            payment_year,
            '-',
            '0',
            payment_month,
            '-01'
        ),
        '%Y-%m-%d'
    ) as payment_date,
    row_num,
    CONCAT(lastName, ' ', firstName),
    turnover
FROM
    employee_rank
WHERE
    row_num = '1'
    or row_num = '2'
ORDER BY
    1 DESC,
    row_num);
    
SELECT offices.country, 
SUM(payments.amount) as turnover
FROM offices
JOIN employees 
ON offices.officeCode = employees.officeCode
JOIN customers 
ON employees.employeeNumber = customers.salesRepEmployeeNumber
JOIN payments
ON customers.customerNumber = payments.customerNumber
WHERE YEAR(payments.paymentDate) = YEAR(CURDATE())
GROUP BY offices.country;



SELECT offices.country, 
COUNT(employeeNumber) as nb_employee
FROM offices
JOIN employees 
ON offices.officeCode = employees.officeCode
GROUP BY offices.country;


select employees.employeeNumber, CONCAT(lastName, ' ', firstName) as employee, 
SUM(amount) as turnover
FROM employees
JOIN customers
ON employees.employeeNumber = customers.salesRepEmployeeNumber
JOIN payments
on customers.customerNumber = payments.customerNumber
WHERE YEAR(payments.paymentDate) = YEAR(CURDATE())
GROUP BY employeeNumber
ORDER BY turnover DESC
LIMIT 1 ;

#Logistique : 5produits les plus commandés

SELECT products.productName, SUM(orderdetails.quantityOrdered) as total
from products
JOIN orderdetails ON products.productCode = orderdetails.productCode
GROUP BY products.productName
ORDER BY total DESC
LIMIT 5;

#Stock des 5 produits commandés

SELECT products.productName,quantityInstock,
SUM(orderdetails.quantityOrdered) as totalOrdered
from products
JOIN orderdetails ON products.productCode = orderdetails.productCode
GROUP BY products.productName,quantityInstock
ORDER BY totalOrdered DESC
LIMIT 5;
    
    
 -- finance
 --Turnover of orders or last 2 months by country
CREATE VIEW Orders_2Months AS (

SELECT c.country Country, SUM(quantityOrdered*priceEach) TurnOver
FROM orderdetails od
JOIN orders o ON od.orderNumber=o.orderNumber
JOIN customers c ON o.customerNumber=c.customerNumber
WHERE orderDate >= now()-interval 2 month
GROUP BY c.country
ORDER BY 2 DESC

                    );


select od.orderDate from Orders_2Months;


--Not Paid Orders
CREATE VIEW Unpaid_Orders AS (

SELECT p.productLine Product, SUM(d.quantityOrdered) as Quantity
FROM orderdetails d
JOIN orders o ON o.orderNumber = d.orderNumber
JOIN products p ON p.productCode = d.productCode
WHERE o.shippedDate IS NULL
AND o.status IN ('On Hold', 'Cancelled', 'Resolved')
GROUP BY productLine
ORDER BY Quantity

                                );


select * from Unpaid_Orders;

-- SALES
WITH tablefinale AS (
    SELECT
        MONTH(orderDate) AS order_month,
        YEAR(orderDate) AS order_year,
        productLine,
        SUM(quantityOrdered) AS amount
    FROM
        orderdetails
        JOIN products ON orderdetails.productCode = products.productCode
        JOIN orders ON orders.orderNumber = orderdetails.orderNumber
    WHERE
        orders.status <> 'Cancelled'
        AND orders.status <> 'ON Hold'
        AND YEAR(orderDate) <> '2019'
    GROUP BY
        productLine,
        YEAR(orders.orderDate),
        MONTH(orders.orderDate)
)
SELECT
    t1.productLine,
    STR_TO_DATE(
        CONCAT(t1.order_year, '-', '0', t1.order_month, '-01'),
        '%Y-%m-%d'
    ) AS `date`,
    IFNULL(
        STR_TO_DATE(
            CONCAT(t2.order_year, '-', '0', t2.order_month, '-01'),
            '%Y-%m-%d'
        ),
        STR_TO_DATE(
            CONCAT(
                t1.order_year - 1,
                '-',
                '0',
                t1.order_month,
                '-01'
            ),
            '%Y-%m-%d'
        )
    ) AS year_minus_1,
    IFNULL(t1.amount, 0) AS amount_T,
    IFNULL(t2.amount, 0) AS amount_T_minus_1,
    IFNULL((t1.amount - t2.amount), t1.amount) AS Year_over_year_comparison,
    IFNULL(
        CONCAT(
            FORMAT(
                (
                    (t1.amount - t2.amount) / t2.amount * 100
                ),
                0
            ),
            '%'
        ),
        0
    ) AS Year_over_year_growth_rate
FROM
    tablefinale t1
    LEFT JOIN tablefinale t2 ON t1.productLine = t2.productLine
    AND t1.order_month = t2.order_month
    AND t2.order_year + 1 = t1.order_year
HAVING
    YEAR(`date`) LIKE '2021%'
ORDER BY
    2 DESC, 1 ASC;
