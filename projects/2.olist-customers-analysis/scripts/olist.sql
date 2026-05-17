--创建数据库
CREATE DATABASE IF NOT EXISTS db_ecommerce;
--切换数据库
USE db_ecommerce;

--建表
CREATE TABLE IF NOT EXISTS olist_customers (
    customer_id STRING COMMENT '客户ID',
    customer_unique_id STRING COMMENT '唯一客户ID',
    customer_zip_code_prefix STRING COMMENT '邮编前缀',
    customer_city STRING COMMENT '城市',
    customer_state STRING COMMENT '州'
) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

-- 查看表结构
DESC olist_customers;

-- 加载数据到表中
load data local inpath '/home/hadoop/data/olist_customers_dataset.csv' into table olist_customers;

-- 删除表
DROP TABLE tb_deals_cleaned;

-- 删除标题行
INSERT OVERWRITE TABLE olist_customers
SELECT * FROM olist_customers WHERE customer_id != 'customer_id';

--ETL
-- 清洗客户表：去重、去引号、标准化字段
CREATE TABLE IF NOT EXISTS tb_customers_cleaned AS
SELECT 
    REGEXP_REPLACE(customer_id, '^"|"$', '') AS customer_id,
    REGEXP_REPLACE(customer_unique_id, '^"|"$', '') AS customer_unique_id,
    REGEXP_REPLACE(customer_unique_id, '^"|"$', '') AS customer_zip_code_prefix,
    INITCAP(REGEXP_REPLACE(customer_city, '^"|"$', '')) AS customer_city,
    UPPER(REGEXP_REPLACE(customer_state, '^"|"$', '')) AS customer_state
FROM olist_customers
WHERE customer_id IS NOT NULL 
  AND customer_id != 'customer_id'
  AND customer_state IS NOT NULL;


-- 验证清洗结果
SELECT '清洗前客户数' AS metric, COUNT(*) AS count FROM olist_customers
UNION ALL
SELECT '清洗后客户数' AS metric, COUNT(*) AS count FROM tb_customers_cleaned;



-- 创建去重后的客户表（每个唯一客户只保留一条记录）
CREATE TABLE IF NOT EXISTS tb_unique_customers
COMMENT "创建去重后的客户表" AS
SELECT 
    customer_unique_id,
    MAX(customer_zip_code_prefix) AS customer_zip_code_prefix,
    MAX(customer_city) AS customer_city,
    MAX(customer_state) AS customer_state,
    COUNT(*) AS order_count
FROM tb_customers_cleaned
GROUP BY customer_unique_id;





-- 验证清洗结果
SELECT '原始数据行数' AS metric, COUNT(*) AS count FROM tb_customers
UNION ALL
SELECT '清洗后行数' AS metric, COUNT(*) AS count FROM tb_customers_cleaned
UNION ALL
SELECT '去重客户数' AS metric, COUNT(*) AS count FROM tb_unique_customers;









-- Q1：各州客户数量分布
CREATE TABLE IF NOT EXISTS tb_rs_state_distribution
COMMENT "各州客户数量分布" AS
SELECT 
    customer_state,
    COUNT(*) AS customer_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tb_customers_cleaned), 2) AS percentage
FROM tb_customers_cleaned
GROUP BY customer_state
ORDER BY customer_count DESC;

-- Q2：TOP 20 城市客户数量
CREATE TABLE IF NOT EXISTS tb_rs_top_cities
COMMENT "TOP 20 城市客户数量"  AS
SELECT 
    customer_state,
    customer_city,
    COUNT(*) AS customer_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM tb_customers_cleaned
GROUP BY customer_state, customer_city
ORDER BY customer_count DESC
LIMIT 20;

-- Q3：重复购买客户分析（同一unique_id出现多次）
CREATE TABLE IF NOT EXISTS tb_rs_repeat_customers
COMMENT "重复购买客户分析" AS
SELECT 
    CASE 
        WHEN order_count = 1 THEN '单次购买'
        WHEN order_count = 2 THEN '2次购买'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5次购买'
        ELSE '5次以上'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tb_unique_customers), 2) AS percentage
FROM tb_unique_customers
GROUP BY 
    CASE 
        WHEN order_count = 1 THEN '单次购买'
        WHEN order_count = 2 THEN '2次购买'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5次购买'
        ELSE '5次以上'
    END
ORDER BY customer_count DESC;

-- Q4：常见邮编前缀区域分布
CREATE TABLE IF NOT EXISTS tb_rs_zip_prefix
COMMENT "常见邮编前缀区域分布" AS
SELECT 
    customer_zip_code_prefix,
    customer_state,
    COUNT(*) AS customer_count
FROM tb_customers_cleaned
GROUP BY customer_zip_code_prefix, customer_state
ORDER BY customer_count DESC
LIMIT 30;

-- 总客户数,唯一客户,州数,城市数
CREATE TABLE IF NOT EXISTS tb_rs_customers_cnt
COMMENT "总客户数,唯一客户,州数,城市数" AS
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(DISTINCT customer_state) AS state_count,
    COUNT(DISTINCT customer_city) AS city_count
FROM tb_customers_cleaned;



--------------------------------------------------关于表olist_sellers_dataset.csv-----------------------------------
-- 创建卖家表
CREATE TABLE IF NOT EXISTS olist_sellers_dataset (
    seller_id STRING COMMENT '卖家唯一标识',
    seller_zip_code_prefix STRING COMMENT '卖家邮编前缀',
    seller_city STRING COMMENT '卖家城市',
    seller_state STRING COMMENT '卖家州'
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar" = "\"",
    "escapeChar" = "\\"
)
STORED AS TEXTFILE
TBLPROPERTIES ("skip.header.line.count"="1");

-- 加载数据
LOAD DATA INPATH '/archive/olist_sellers_dataset.csv' 
OVERWRITE INTO TABLE olist_sellers_dataset;

-- 1. 卖家总数
CREATE TABLE tb_rs_total_sellers COMMENT '卖家总数统计' AS
SELECT COUNT(DISTINCT seller_id) AS total_sellers 
FROM olist_sellers_dataset;

-- 2. 城市分布统计（Top 20）
CREATE TABLE tb_rs_seller_city_distribution COMMENT '卖家城市分布TOP20' AS
SELECT 
    seller_state,
    seller_city,
    COUNT(DISTINCT seller_id) AS seller_count
FROM olist_sellers_dataset
GROUP BY seller_state, seller_city
ORDER BY seller_count DESC
LIMIT 20;

-- 3. 各州卖家分布（含百分比）
CREATE TABLE tb_rs_seller_state_distribution COMMENT '各州卖家分布及占比' AS
SELECT 
    seller_state,
    COUNT(DISTINCT seller_id) AS seller_count,
    ROUND(COUNT(DISTINCT seller_id) * 100.0 / (SELECT COUNT(DISTINCT seller_id) FROM olist_sellers_dataset), 2) AS percentage
FROM olist_sellers_dataset
GROUP BY seller_state
ORDER BY seller_count DESC;

-- 4. 卖家最集中的TOP10城市
CREATE TABLE tb_rs_top10_seller_cities COMMENT '卖家最集中的TOP10城市' AS
SELECT 
    seller_city,
    seller_state,
    COUNT(DISTINCT seller_id) AS seller_count
FROM olist_sellers_dataset
GROUP BY seller_city, seller_state
ORDER BY seller_count DESC
LIMIT 10;

-- 5. 卖家密度分析（同一邮编前缀的卖家数）
CREATE TABLE tb_rs_seller_zip_density COMMENT '卖家密度分析-按邮编前缀' AS
SELECT 
    seller_zip_code_prefix,
    COUNT(DISTINCT seller_id) AS seller_count
FROM olist_sellers_dataset
GROUP BY seller_zip_code_prefix
ORDER BY seller_count DESC
LIMIT 20;

-- 6. 空值检查统计
CREATE TABLE tb_rs_null_check_sellers COMMENT '卖家表空值检查' AS
SELECT 
    SUM(CASE WHEN seller_id IS NULL OR seller_id = '' THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL OR seller_zip_code_prefix = '' THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN seller_city IS NULL OR seller_city = '' THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN seller_state IS NULL OR seller_state = '' THEN 1 ELSE 0 END) AS null_state,
    COUNT(*) AS total_rows
FROM olist_sellers_dataset;

-- 7. 重复卖家检查
CREATE TABLE tb_rs_dup_sellers COMMENT '重复卖家检查' AS
SELECT seller_id, COUNT(*) AS dup_count
FROM olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1;