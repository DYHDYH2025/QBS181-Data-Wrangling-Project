CREATE TABLE final_analytics_base_table (
    id VARCHAR(20),
    name TEXT,
    host_id VARCHAR(20),
    host_identity_verified VARCHAR(30),
    host_name TEXT,
    neighbourhood_group VARCHAR(50),
    neighbourhood VARCHAR(50),
    instant_bookable VARCHAR(10),
    cancellation_policy VARCHAR(30),
    room_type VARCHAR(30),
    construction_year INT,
    price DOUBLE,
    service_fee DOUBLE,
    minimum_nights INT,
    number_of_reviews INT,
    last_review DATE,
    reviews_per_month DOUBLE,
    review_rate_number DOUBLE,
    calculated_host_listings_count INT,
    availability_365 INT,
    house_rules TEXT,
    GEOID_x VARCHAR(15),
    NAME_x VARCHAR(30),
    variable VARCHAR(50),
    estimate DOUBLE,
    moe DOUBLE,
    STATEFP VARCHAR(10),
    COUNTYFP VARCHAR(10),
    COUNTYNS VARCHAR(20),
    AFFGEOID VARCHAR(50),
    GEOID_y VARCHAR(15),
    NAME_y VARCHAR(50),
    NAMELSAD VARCHAR(50),
    STUSPS VARCHAR(10),
    STATE_NAME VARCHAR(50),
    LSAD VARCHAR(10),
    ALAND BIGINT,
    AWATER BIGINT
);

-- Load Data
LOAD DATA LOCAL INFILE '/home/michael/QBS181/Final-project/data/final_analytics_base_table.csv'
INTO TABLE final_analytics_base_table
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS;

-- Create Wide Table with Aggregation
CREATE TABLE final_analytics_base_table_wide AS
SELECT
    id,
    name,
    host_id,
    host_identity_verified,
    host_name,
    neighbourhood_group,
    neighbourhood,
    instant_bookable,
    cancellation_policy,
    room_type,
    construction_year,
    price,
    service_fee,
    minimum_nights,
    number_of_reviews,
    last_review,
    reviews_per_month,
    review_rate_number,
    calculated_host_listings_count,
    availability_365,
    house_rules,
    GEOID_x,
    NAME_x,
    MAX(CASE WHEN variable = 'median_income' THEN estimate END) AS median_income,
    MAX(CASE WHEN variable = 'population' THEN estimate END) AS population,
    MAX(CASE WHEN variable = 'median_rent' THEN estimate END) AS median_rent
FROM final_analytics_base_table
GROUP BY
    id, name, host_id, host_identity_verified, host_name,
    neighbourhood_group, neighbourhood, instant_bookable, cancellation_policy,
    room_type, construction_year, price, service_fee, minimum_nights,
    number_of_reviews, last_review, reviews_per_month, review_rate_number,
    calculated_host_listings_count, availability_365, house_rules,
    GEOID_x, NAME_x;

-- Export Data to CSV
SELECT * FROM final_analytics_base_table_wide
INTO OUTFILE '/var/lib/mysql-files/final_analytics_base_table_wide_preview.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- Find String Columns
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'final_analytics_base_table_wide'
AND TABLE_SCHEMA = 'qbs181'
AND DATA_TYPE IN ('varchar', 'text', 'longtext', 'mediumtext', 'char');

-- Check for Newlines in house_rules
SELECT id, LENGTH(house_rules), LOCATE('\n', house_rules) AS newline_pos
FROM final_analytics_base_table_wide
WHERE LOCATE('\n', house_rules) > 0
LIMIT 5;

-- Export Clean Data with REPLACE Function
SELECT
    REPLACE(REPLACE(REPLACE(id, '\r', ' '), '\n', ' '), '"', "'") AS id,
    REPLACE(REPLACE(REPLACE(name, '\r', ' '), '\n', ' '), '"', "'") AS name,
    REPLACE(REPLACE(REPLACE(host_id, '\r', ' '), '\n', ' '), '"', "'") AS host_id,
    REPLACE(REPLACE(REPLACE(host_identity_verified, '\r', ' '), '\n', ' '), '"', "'") AS host_identity_verified,
    REPLACE(REPLACE(REPLACE(host_name, '\r', ' '), '\n', ' '), '"', "'") AS host_name,
    REPLACE(REPLACE(REPLACE(neighbourhood_group, '\r', ' '), '\n', ' '), '"', "'") AS neighbourhood_group,
    REPLACE(REPLACE(REPLACE(neighbourhood, '\r', ' '), '\n', ' '), '"', "'") AS neighbourhood,
    REPLACE(REPLACE(REPLACE(instant_bookable, '\r', ' '), '\n', ' '), '"', "'") AS instant_bookable,
    REPLACE(REPLACE(REPLACE(cancellation_policy, '\r', ' '), '\n', ' '), '"', "'") AS cancellation_policy,
    REPLACE(REPLACE(REPLACE(room_type, '\r', ' '), '\n', ' '), '"', "'") AS room_type,
    construction_year,
    price,
    service_fee,
    minimum_nights,
    number_of_reviews,
    last_review,
    reviews_per_month,
    review_rate_number,
    calculated_host_listings_count,
    availability_365,
    REPLACE(REPLACE(REPLACE(house_rules, '\r', ' '), '\n', ' '), '"', "'") AS house_rules,
    REPLACE(REPLACE(REPLACE(GEOID_x, '\r', ' '), '\n', ' '), '"', "'") AS GEOID_x,
    REPLACE(REPLACE(REPLACE(NAME_x, '\r', ' '), '\n', ' '), '"', "'") AS NAME_x,
    median_income,
    population,
    median_rent
FROM final_analytics_base_table_wide
INTO OUTFILE '/var/lib/mysql-files/final_analytics_base_table_wide_clean.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';