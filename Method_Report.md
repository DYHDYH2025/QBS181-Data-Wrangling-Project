# Methods Report: NYC Airbnb Data Wrangling Project

## Executive Summary

This document provides a comprehensive overview of the methodologies employed in the QBS181 Data Wrangling Project, which focuses on cleaning, integrating, analyzing, and visualizing Airbnb listing data for New York City. The project integrates multiple data sources, applies spatial analysis techniques, and employs statistical modeling to understand the relationships between Airbnb pricing and neighborhood socioeconomic factors.

---

## Table of Contents

1. [Data Sources](#1-data-sources)
2. [Data Cleaning Methods](#2-data-cleaning-methods)
3. [Data Integration Methods](#3-data-integration-methods)
4. [Spatial Analysis Methods](#4-spatial-analysis-methods)
5. [Statistical Modeling Methods](#5-statistical-modeling-methods)
6. [Visualization Methods](#6-visualization-methods)
7. [Database Management Methods](#7-database-management-methods)
8. [Quality Assurance Methods](#8-quality-assurance-methods)
9. [Technical Implementation](#9-technical-implementation)

---

## 1. Data Sources

### 1.1 Primary Data: NYC Airbnb Listings

- **Source**: Inside Airbnb (http://insideairbnb.com/get-the-data.html)
- **Format**: CSV/Excel file (`Airbnb_Open_Data.xlsx`)
- **Temporal Coverage**: 2019 listings
- **Key Variables**:
  - Listing identifiers (id, host_id)
  - Location data (latitude, longitude, neighbourhood_group, neighbourhood)
  - Property characteristics (room_type, construction_year, price, service_fee)
  - Availability metrics (minimum_nights, availability_365)
  - Review metrics (number_of_reviews, reviews_per_month, last_review)
  - Host information (host_name, host_identity_verified, calculated_host_listings_count)

### 1.2 Secondary Data: American Community Survey (ACS)

- **Source**: U.S. Census Bureau via `tidycensus` R package
- **Survey Type**: ACS 5-year estimates (2020)
- **Geographic Unit**: ZIP Code Tabulation Areas (ZCTAs)
- **Key Variables**:
  - `B19013_001`: Median household income
  - `B01003_001`: Total population
  - `B25064_001`: Median gross rent
- **Spatial Coverage**: Filtered to NYC five boroughs (New York, Kings, Queens, Bronx, Richmond)

### 1.3 Geocoding Service

- **Service**: Nominatim (OpenStreetMap) via `geopy` Python library
- **Purpose**: Reverse geocoding to fill missing neighborhood information
- **API Endpoint**: https://nominatim.openstreetmap.org/
- **Rate Limiting**: 1 request per second (as per service terms)

---

## 2. Data Cleaning Methods

### 2.1 Column Name Standardization

**Method**: `janitor::clean_names()`

**Rationale**: Standardize column names to follow consistent naming conventions (snake_case), improving code readability and preventing errors from inconsistent naming.

**Implementation**:
```r
df_cleaned_first <- read_csv(file_path) %>% 
  clean_names()
```

**Output**: All column names converted to lowercase with underscores replacing spaces and special characters.

### 2.2 Data Type Conversion

**Method**: Explicit type casting using `as.numeric()`

**Variables Converted**:
- `price`: Converted from character/string to numeric
- `service_fee`: Converted from character/string to numeric

**Rationale**: Ensure numeric operations can be performed on price-related variables and prevent type-related errors in downstream analysis.

**Implementation**:
```r
df_cleaned_second <- df_cleaned_first %>%
  mutate(
    price = as.numeric(price),
    service_fee = as.numeric(service_fee)
  )
```

### 2.3 Missing Value Imputation

**Method**: Median imputation for numeric variables

**Variables Treated**:
- `reviews_per_month`: Missing values replaced with median
- `availability_365`: Missing values replaced with median

**Rationale**: 
- Median is robust to outliers compared to mean
- Preserves the distribution characteristics of the data
- Appropriate for variables that may have skewed distributions

**Implementation**:
```r
median_reviews_per_month <- df_cleaned_first %>% 
  pull(reviews_per_month) %>% 
  median(na.rm = TRUE)

median_availability <- df_cleaned_first %>% 
  pull(availability_365) %>% 
  median(na.rm = TRUE)

df_cleaned_second <- df_cleaned_first %>%
  mutate(
    reviews_per_month = replace_na(reviews_per_month, median_reviews_per_month),
    availability_365 = replace_na(availability_365, median_availability)
  )
```

### 2.4 Date Standardization and Cleaning

**Method**: Date parsing and outlier treatment

**Process**:
1. Parse date strings using `lubridate::mdy()` to handle various date formats
2. Identify valid dates (within reasonable range, e.g., before 2021-01-01)
3. Calculate median of valid dates
4. Replace missing dates and out-of-range dates with median date

**Rationale**: 
- Standardize date formats for consistency
- Handle data quality issues (future dates, invalid dates)
- Use median as robust central tendency measure for imputation

**Implementation**:
```r
df_cleaned_second <- df_cleaned_second %>%
  mutate(last_review = lubridate::mdy(last_review))

current_date_limit <- as.Date("2021-01-01")
median_review_date <- df_cleaned_second %>% 
  filter(!is.na(last_review) & last_review <= current_date_limit) %>% 
  pull(last_review) %>% 
  median(na.rm = TRUE)

df_cleaned_second <- df_cleaned_second %>%
  mutate(
    last_review = if_else(
      is.na(last_review) | last_review > current_date_limit, 
      median_review_date, 
      last_review
    )
  )
```

### 2.5 Outlier Treatment for Minimum Nights

**Method**: Boundary enforcement using `case_when()`

**Logic**:
- Values ≤ 0 → set to 1 (minimum logical value)
- Values > 365 → set to 365 (maximum logical value)
- Values between 1-365 → keep original value

**Rationale**: 
- Remove logically impossible values (negative or zero minimum nights)
- Cap extreme outliers that may represent data entry errors
- Preserve valid data while cleaning problematic entries

**Implementation**:
```r
df_cleaned_second <- df_cleaned_second %>%
  mutate(
    minimum_nights = case_when(
      minimum_nights <= 0 ~ 1,
      minimum_nights > 365 ~ 365,
      TRUE ~ minimum_nights 
    )
  )
```

---

## 3. Data Integration Methods

### 3.1 Reverse Geocoding for Missing Location Data

**Method**: Python-based reverse geocoding using Nominatim API

**Purpose**: Fill missing `neighbourhood_group` and `neighbourhood` values using latitude and longitude coordinates.

**Implementation Details**:
1. **Rate Limiting**: Implemented `RateLimiter` with 1-second delay between requests to comply with API terms of service
2. **Error Handling**: 
   - Retry mechanism (up to 3 attempts) for timeout errors
   - Exception handling for service errors
   - Fallback values for failed geocoding attempts
3. **Timeout Handling**: Increased timeout to 10 seconds to handle slow API responses

**Algorithm**:
```python
# Identify rows needing geocoding
rows_to_geocode = df[
    (df['neighbourhood_group'] == 'Unknown') | 
    (df['neighbourhood'].isna())
].copy()

# Configure geocoder with rate limiting
geolocator = Nominatim(
    user_agent="airbnb_nyc_analysis_script", 
    timeout=10
)
geocode_limited = RateLimiter(
    geolocator.reverse, 
    min_delay_seconds=1.0
)

# Apply reverse geocoding with retry logic
def get_location_info(row):
    MAX_RETRIES = 3
    for attempt in range(MAX_RETRIES):
        try:
            location = geocode_limited((row['lat'], row['long']))
            # Extract borough and neighbourhood from address components
            # Return pd.Series([group, hood])
        except GeocoderTimedOut:
            # Retry with exponential backoff
            time.sleep(2 * (attempt + 1))
            continue
    return pd.Series([None, None])
```

**Output**: Enhanced dataset with complete location information for all listings.

### 3.2 ACS Data Retrieval

**Method**: `tidycensus::get_acs()` for programmatic data access

**Process**:
1. **API Authentication**: Configure Census API key using `census_api_key()`
2. **Data Retrieval**: Download ZCTA-level ACS 5-year estimates for 2020
3. **Variable Selection**: Extract median income, population, and median rent
4. **Spatial Filtering**: Filter to NYC five boroughs using spatial intersection

**Implementation**:
```r
# Download national ZCTA data
zcta_data <- get_acs(
  geography = "zcta",
  variables = c(
    median_income = "B19013_001", 
    population = "B01003_001",
    median_rent = "B25064_001"
  ),
  year = 2020,
  geometry = TRUE
)

# Get NYC county boundaries
nyc_counties <- counties(state = "NY", cb = TRUE, year = 2020) %>%
  filter(NAME %in% c("New York", "Kings", "Queens", "Bronx", "Richmond"))

# Spatial filter to NYC ZCTAs
nyc_acs_data <- st_join(
  zcta_data, 
  nyc_counties, 
  join = st_intersects, 
  left = FALSE
)
```

**Output**: Spatial data frame containing ACS variables for NYC ZCTAs with geometry information.

---

## 4. Spatial Analysis Methods

### 4.1 Spatial Data Transformation

**Method**: Convert tabular data to spatial objects using `sf` package

**Process**:
1. **Point Creation**: Convert Airbnb listings (with lat/long) to `sf` point objects
2. **Coordinate Reference System (CRS)**: Set to WGS84 (EPSG:4326) for consistency
3. **Geometry Validation**: Filter out rows with missing coordinates

**Implementation**:
```r
airbnb_data_final_cleaned_sf <- airbnb_data_final_cleaned %>%
  filter(!is.na(long) & !is.na(lat)) %>%
  st_as_sf(coords = c("long", "lat"), crs = 4326)
```

### 4.2 Coordinate Reference System (CRS) Alignment

**Method**: `st_transform()` for CRS standardization

**Rationale**: Ensure all spatial data use the same coordinate system for accurate spatial operations.

**Implementation**:
```r
nyc_acs_data_transformed <- st_transform(nyc_acs_data, crs = 4326)
```

### 4.3 Spatial Join

**Method**: `st_join()` with `st_intersects` predicate

**Purpose**: Attach ACS socioeconomic variables to Airbnb listings based on spatial location.

**Algorithm**:
- For each Airbnb listing (point), find the ZCTA polygon that contains it
- Attach all ACS variables from the matching ZCTA to the listing
- Result: Each listing enriched with neighborhood-level socioeconomic data

**Implementation**:
```r
joined_data_sf <- st_join(
  airbnb_data_final_cleaned_sf, 
  nyc_acs_data_transformed, 
  join = st_intersects
)
```

**Output**: Spatial data frame with Airbnb listings and associated ACS variables.

### 4.4 Geometry Removal for Modeling

**Method**: `st_drop_geometry()` to convert spatial objects to regular data frames

**Rationale**: Remove geometry information for statistical modeling, as most modeling algorithms do not require spatial geometry.

**Implementation**:
```r
final_analytics_base_table <- joined_data_sf %>%
  st_drop_geometry() %>%
  as.data.frame()
```

---

## 5. Statistical Modeling Methods

### 5.1 Data Preparation for Modeling

**Method**: Feature selection and transformation

**Variables Selected**:
- **Categorical**: `room_type`, `neighbourhood_group`, `cancellation_policy`
- **Numeric**: `minimum_nights`, `number_of_reviews`, `availability_365`, `service_fee`, `reviews_per_month`
- **Socioeconomic**: `median_income`, `population`, `median_rent`
- **Target Variable**: `price` (log-transformed)

**Data Filtering**:
- Remove listings with price ≤ 0
- Remove listings with missing `median_income`
- Remove listings with missing `room_type`
- Remove listings with missing `neighbourhood_group`

**Implementation**:
```sql
SELECT
  id, neighbourhood_group, cancellation_policy, room_type,
  construction_year, price AS price_numeric,
  LOG(price) AS log_price,
  minimum_nights, number_of_reviews, availability_365,
  service_fee, reviews_per_month, GEOID_x,
  median_income, population, median_rent
FROM final_data
WHERE price > 0
  AND median_income IS NOT NULL
  AND room_type IS NOT NULL
  AND neighbourhood_group IS NOT NULL;
```

### 5.2 Log Transformation of Response Variable

**Method**: Natural logarithm transformation of price

**Rationale**:
- Price distributions are typically right-skewed
- Log transformation reduces skewness and makes distribution more normal
- Improves model assumptions (linearity, homoscedasticity)
- Allows interpretation of coefficients as percentage changes

**Implementation**:
```r
model_data <- model_data %>%
  mutate(log_price = log(price))
```

### 5.3 Multiple Linear Regression

**Method**: Ordinary Least Squares (OLS) regression using `lm()`

**Model Specification**:
```
log_price ~ room_type + neighbourhood_group + minimum_nights +
            number_of_reviews + availability_365 + 
            median_income + median_rent + cancellation_policy
```

**Rationale**: 
- Linear regression is interpretable and provides coefficient estimates
- Allows testing of individual variable effects
- Provides R² for model fit assessment
- Enables hypothesis testing via p-values

**Implementation**:
```r
mlr_model <- lm(
  log_price ~ room_type + neighbourhood_group + minimum_nights +
              number_of_reviews + availability_365 + 
              median_income + median_rent + cancellation_policy,
  data = model_data
)
```

### 5.4 Model Diagnostics

#### 5.4.1 Variance Inflation Factor (VIF)

**Method**: `car::vif()` to assess multicollinearity

**Purpose**: Detect high correlation between predictor variables that may inflate variance of coefficient estimates.

**Interpretation**:
- VIF < 5: Low multicollinearity (acceptable)
- VIF 5-10: Moderate multicollinearity (caution)
- VIF > 10: High multicollinearity (problematic)

**Implementation**:
```r
run_model_diagnostics <- function(model) {
  if (length(coef(model)) > 2) {
    vif_results <- car::vif(model)
    print(vif_results)
  }
}
```

**Findings**: 
- `median_income` VIF ≈ 8.1 (moderate multicollinearity)
- `median_rent` VIF ≈ 7.8 (moderate multicollinearity)
- **Recommendation**: Remove one of these variables in future models

#### 5.4.2 Residual Diagnostics

**Method**: Standard residual plots from `plot(model)`

**Plots Generated**:
1. **Residuals vs. Fitted**: Assess linearity assumption
2. **Normal Q-Q Plot**: Assess normality of residuals
3. **Scale-Location Plot**: Assess homoscedasticity (constant variance)
4. **Residuals vs. Leverage**: Identify influential observations

**Implementation**:
```r
par(mfrow = c(2, 2))
plot(model)
par(mfrow = c(1, 1))
```

**Findings**:
- Linearity: Approximately satisfied
- Normality: Residuals deviate from normality (S-shaped Q-Q plot)
- Homoscedasticity: Mild heteroscedasticity detected
- Leverage: A few high-leverage observations detected (not severe)

#### 5.4.3 Model Performance Assessment

**Metrics**:
- **R²**: Proportion of variance explained by the model
- **Adjusted R²**: R² adjusted for number of predictors
- **F-statistic**: Overall model significance test
- **p-values**: Individual coefficient significance tests

**Findings**:
- R² = 0.0003 (extremely low explanatory power)
- Only `median_rent` is statistically significant (p ≈ 0.037)
- **Conclusion**: Model has poor predictive performance, suggesting missing key variables

---

## 6. Visualization Methods

### 6.1 Static Visualizations

#### 6.1.1 Categorical Distribution Plots

**Method**: Bar charts using `ggplot2::geom_col()`

**Visualizations**:
- **Borough Distribution**: Count of listings by `neighbourhood_group`
- **Room Type Distribution**: Count of listings by `room_type`
- **Stacked Bar Chart**: Room type composition by borough

**Implementation**:
```r
# Borough distribution
borough_data <- data %>%
  count(neighbourhood_group, name = "n") %>%
  mutate(neighbourhood_group = fct_reorder(neighbourhood_group, n, .desc = TRUE))

ggplot(borough_data, aes(x = neighbourhood_group, y = n)) +
  geom_col(fill = "#56B4E9") +
  labs(title = "NYC Airbnb Listing Count by Borough",
       x = "Borough", y = "Number of Listings")
```

#### 6.1.2 Choropleth Maps

**Method**: `ggplot2::geom_sf()` with `scale_fill_viridis_c()`

**Purpose**: Visualize spatial distribution of socioeconomic variables (e.g., median income) across NYC ZCTAs.

**Implementation**:
```r
plot_income_map <- function(nyc_acs_wide) {
  ggplot(nyc_acs_wide) +
    geom_sf(aes(fill = median_income), color = NA) +
    scale_fill_viridis_c(
      option = "plasma",
      labels = scales::dollar,
      na.value = "grey90"
    ) +
    labs(title = "Median Household Income by ZIP Code (NYC, 2020)",
         fill = "Median Income ($)")
}
```

#### 6.1.3 Scatter Point Maps

**Method**: `ggplot2::geom_point()` with geographic coordinates

**Purpose**: Visualize spatial distribution of Airbnb listings colored by price.

**Implementation**:
```r
plot_airbnb_prices <- function(model_data, max_price = 1000) {
  ggplot(data = model_data %>% filter(price_numeric < max_price)) +
    geom_point(aes(x = long, y = lat, color = price_numeric),
               size = 0.7, alpha = 0.6) +
    scale_color_viridis_c(option = "inferno", trans = "log",
                          name = "Price (log scale)",
                          labels = scales::dollar) +
    coord_equal() +
    labs(title = "NYC Airbnb Price Distribution",
         x = "Longitude", y = "Latitude")
}
```

### 6.2 Interactive Visualizations

#### 6.2.1 Leaflet Maps

**Method**: `leaflet` package for interactive web maps

**Features**:
- Zoom and pan functionality
- Popup information on marker click
- Color-coded markers based on price (log scale)
- Legend with price ranges

**Implementation**:
```r
pal <- colorNumeric(palette = "magma", domain = data_for_map$price_log)

leaflet(data_for_map) %>%
  addProviderTiles("CartoDB.PositronNoLabels") %>%
  addCircleMarkers(
    lng = ~long, lat = ~lat,
    radius = 1, stroke = FALSE, fillOpacity = 0.2,
    color = ~pal(price_log),
    popup = ~paste("<b>Name:</b>", name, "<br>",
                   "<b>Price:</b> $", price, "<br>",
                   "<b>Neighbourhood:</b>", neighbourhood)
  ) %>%
  addLegend(pal = pal, values = ~price_log, title = "Price (Log10)")
```

#### 6.2.2 Plotly Scatter Maps

**Method**: `plotly::plot_ly()` with `scattermapbox` type

**Purpose**: Interactive exploration of listings by room type with mapbox integration.

**Implementation**:
```r
plot_ly(data_sample, 
        x = ~long, y = ~lat, color = ~room_type,
        type = 'scattermapbox', mode = 'markers',
        marker = list(size = 5, opacity = 0.5)) %>%
  layout(title = 'Interactive Map of NYC Listings by Room Type',
         mapbox = list(style = 'carto-positron',
                       zoom = 9.5,
                       center = list(lon = -73.97, lat = 40.72)))
```

### 6.3 Distribution Plots

**Method**: Histograms and density plots

**Purpose**: Visualize distribution of continuous variables (e.g., minimum nights, price).

**Implementation**:
```r
ggplot(data_to_plot, aes(x = minimum_nights)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "#56B4E9") +
  geom_density(color = "#003366", linewidth = 1) +
  labs(title = "Distribution of Minimum Nights",
       x = "Minimum Nights", y = "Density")
```

---

## 7. Database Management Methods

### 7.1 Database Schema Design

**Method**: MySQL table creation with appropriate data types

**Table Structure**: `final_analytics_base_table`
- String columns: `VARCHAR` or `TEXT` for text data
- Numeric columns: `DOUBLE` for floating-point numbers, `INT` for integers
- Date columns: `DATE` for date values

**Implementation**:
```sql
CREATE TABLE final_analytics_base_table (
    id VARCHAR(20),
    name TEXT,
    host_id VARCHAR(20),
    neighbourhood_group VARCHAR(50),
    neighbourhood VARCHAR(50),
    room_type VARCHAR(30),
    price DOUBLE,
    service_fee DOUBLE,
    minimum_nights INT,
    number_of_reviews INT,
    last_review DATE,
    reviews_per_month DOUBLE,
    availability_365 INT,
    GEOID_x VARCHAR(15),
    variable VARCHAR(50),
    estimate DOUBLE,
    -- ... additional columns
);
```

### 7.2 Data Import

**Method**: `LOAD DATA LOCAL INFILE` for bulk data import

**Process**:
1. Enable `local_infile=1` in MySQL configuration
2. Specify field delimiters and enclosures
3. Skip header row
4. Load data into table

**Implementation**:
```sql
LOAD DATA LOCAL INFILE '/path/to/final_analytics_base_table.csv'
INTO TABLE final_analytics_base_table
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS;
```

### 7.3 Wide Table Transformation

**Method**: SQL `CASE` statements with `MAX()` aggregation

**Purpose**: Convert long-format data (with `variable` and `estimate` columns) to wide format (separate columns for each variable).

**Implementation**:
```sql
CREATE TABLE final_analytics_base_table_wide AS
SELECT
    id, name, host_id, -- ... other columns
    MAX(CASE WHEN variable = 'median_income' THEN estimate END) AS median_income,
    MAX(CASE WHEN variable = 'population' THEN estimate END) AS population,
    MAX(CASE WHEN variable = 'median_rent' THEN estimate END) AS median_rent
FROM final_analytics_base_table
GROUP BY id, name, host_id, -- ... other columns
```

### 7.4 Text Data Cleaning

**Method**: SQL `REPLACE()` function to remove problematic characters

**Purpose**: Clean text fields by replacing newline characters (`\n`), carriage returns (`\r`), and quotes (`"`) that may cause issues in CSV export.

**Implementation**:
```sql
SELECT
    REPLACE(REPLACE(REPLACE(name, '\r', ' '), '\n', ' '), '"', "'") AS name,
    REPLACE(REPLACE(REPLACE(house_rules, '\r', ' '), '\n', ' '), '"', "'") AS house_rules,
    -- ... other columns
FROM final_analytics_base_table_wide
INTO OUTFILE '/path/to/final_analytics_base_table_wide_clean.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';
```

### 7.5 Data Export

**Method**: `SELECT ... INTO OUTFILE` for CSV export

**Requirements**:
- MySQL user must have `FILE` privilege
- Target directory must be writable by MySQL server
- Path must be absolute (not relative)

**Implementation**:
```sql
SELECT * FROM final_analytics_base_table_wide_clean
INTO OUTFILE '/var/lib/mysql-files/output.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';
```

---

## 8. Quality Assurance Methods

### 8.1 Data Quality Checks

**Method**: Comprehensive data quality assessment

**Checks Performed**:
1. **Missing Values**: Count of missing values per column using `colSums(is.na(data))`
2. **Duplicate Rows**: Count of duplicate records using `sum(duplicated(data))`
3. **Data Types**: Verification of correct data types for each column
4. **Value Ranges**: Summary statistics (`summary()`, `skimr::skim()`) to identify outliers
5. **Spatial Validity**: Verification of coordinate ranges (latitude: -90 to 90, longitude: -180 to 180)

**Implementation**:
```r
check_data_quality <- function(data, print_summary = TRUE) {
  results <- list(
    n_rows = nrow(data),
    n_cols = ncol(data),
    missing_values = colSums(is.na(data)),
    duplicate_rows = sum(duplicated(data)),
    numeric_cols = names(data)[sapply(data, is.numeric)],
    character_cols = names(data)[sapply(data, is.character)]
  )
  
  if (print_summary) {
    cat("=== Data Quality Report ===\n")
    cat("Number of rows:", results$n_rows, "\n")
    cat("Number of columns:", results$n_cols, "\n")
    cat("Duplicate rows:", results$duplicate_rows, "\n")
    cat("\nMissing values by column:\n")
    print(results$missing_values[results$missing_values > 0])
  }
  
  return(results)
}
```

### 8.2 Intermediate Output Verification

**Method**: Row count and summary statistics at each pipeline stage

**Checkpoints**:
1. After initial cleaning: Verify row counts and missing value reduction
2. After geocoding: Verify completion of location data
3. After spatial join: Verify successful attachment of ACS variables
4. After database import: Verify data integrity in MySQL
5. After modeling: Verify model data completeness

**Implementation**:
```r
# Check after cleaning
print(paste("Rows after cleaning:", nrow(df_cleaned_second)))
skimr::skim(df_cleaned_second)

# Check after spatial join
nrow(final_analytics_base_table)
glimpse(final_analytics_base_table)

# Check model data
nrow(model_data)
glimpse(model_data)
```

### 8.3 Model Validation

**Method**: Statistical diagnostics and residual analysis

**Validation Steps**:
1. **Multicollinearity Check**: VIF analysis to identify correlated predictors
2. **Residual Analysis**: Visual inspection of residual plots
3. **Model Assumptions**: Testing linearity, normality, homoscedasticity
4. **Performance Metrics**: R², adjusted R², F-statistic, p-values

**Implementation**: See Section 5.4 (Model Diagnostics)

---

## 9. Technical Implementation

### 9.1 Programming Languages and Tools

**R (Primary)**:
- **Purpose**: Data cleaning, spatial analysis, statistical modeling, visualization
- **Key Packages**: `tidyverse`, `sf`, `tidycensus`, `ggplot2`, `leaflet`, `plotly`, `car`, `DBI`, `RMySQL`
- **Version**: R 4.3+ recommended

**Python (Secondary)**:
- **Purpose**: Reverse geocoding (API integration)
- **Key Libraries**: `pandas`, `geopy`
- **Version**: Python 3.9+

**SQL (Database)**:
- **Purpose**: Data transformation, wide table creation, text cleaning
- **Database**: MySQL 8.0+ or MariaDB 10.5+

### 9.2 Workflow Pipeline

**Stage 1: Data Cleaning** (`Data Cleaning/Data Cleaning.Rmd`)
- Input: Raw Airbnb data CSV
- Process: Column standardization, type conversion, missing value imputation, date cleaning, outlier treatment
- Output: `df_cleaned_second.csv`

**Stage 2: Reverse Geocoding** (`Data Cleaning/df_cleaned_second_geo.py`)
- Input: `df_cleaned_second.csv`
- Process: API-based reverse geocoding for missing location data
- Output: `airbnb_nyc_final_clean.csv`

**Stage 3: ACS Data Retrieval** (`NY-ACS.Rmd`)
- Input: Census API key
- Process: Download ACS data, spatial filtering to NYC
- Output: `Data/nyc_acs_data.csv`

**Stage 4: Spatial Integration** (`Final Analysis Data.Rmd`)
- Input: `airbnb_nyc_final_clean.csv`, `nyc_acs_data.csv`
- Process: Spatial join, coordinate system alignment, wide table transformation
- Output: `final_analytics_base_table.csv`, `final_analytics_base_table_wide.csv`

**Stage 5: Database Processing** (`SQL_Commands.sql`)
- Input: `final_analytics_base_table.csv`
- Process: Database import, wide table creation, text cleaning
- Output: `final_analytics_base_table_wide_clean.csv`, `final_data.csv`

**Stage 6: Statistical Modeling** (`Analysis.Rmd`)
- Input: `final_data.csv` (from database)
- Process: Feature selection, log transformation, regression modeling, diagnostics
- Output: `model_data.csv`, model results, diagnostic plots

**Stage 7: Visualization** (`vis_data.Rmd`)
- Input: `airbnb_nyc_final_clean.csv`
- Process: Static and interactive visualizations
- Output: HTML dashboard, interactive maps, distribution plots

### 9.3 Reproducibility Measures

**Version Control**:
- All scripts and data processing steps documented
- Function library (`Functions_Library.R`) for reusable code
- README files with step-by-step instructions

**Data Versioning**:
- Intermediate outputs saved at each stage
- Clear naming conventions for data files
- Data dictionary documenting all variables

**Environment Management**:
- Package version specifications
- Required dependencies documented
- Installation instructions provided

**Code Organization**:
- Modular functions for common operations
- Consistent coding style
- Comprehensive comments and documentation

### 9.4 Error Handling and Robustness

**API Error Handling**:
- Retry mechanisms for geocoding API calls
- Rate limiting to comply with service terms
- Fallback values for failed API requests

**Data Validation**:
- Type checking and conversion
- Range validation for numeric variables
- Missing value handling strategies

**Spatial Data Validation**:
- Coordinate range validation
- CRS verification and transformation
- Geometry validation

**Database Error Handling**:
- Transaction management for data imports
- Error logging for failed operations
- Data integrity checks

---

## 10. Limitations and Future Improvements

### 10.1 Methodological Limitations

1. **Model Performance**: Low R² (0.0003) indicates poor model fit, suggesting missing key predictors
2. **Multicollinearity**: Moderate correlation between `median_income` and `median_rent` may affect coefficient estimates
3. **Data Quality**: Some listings may have incomplete or inaccurate location data
4. **Temporal Coverage**: Analysis based on 2019 data may not reflect current market conditions
5. **Spatial Resolution**: ZCTA-level socioeconomic data may not capture neighborhood-level variation

### 10.2 Recommended Improvements

1. **Enhanced Feature Engineering**:
   - Include distance to landmarks (Central Park, subway stations, airports)
   - Add temporal features (seasonality, day of week)
   - Include host-level features (superhost status, response rate)

2. **Advanced Modeling Techniques**:
   - Spatial regression models (spatial lag, spatial error)
   - Machine learning models (random forest, gradient boosting)
   - Non-linear transformations and interactions

3. **Data Quality Improvements**:
   - Validation of geocoding results
   - Outlier detection and treatment
   - Missing data imputation using advanced methods (MICE, KNN)

4. **Spatial Analysis Enhancements**:
   - Higher-resolution spatial data (census tracts, block groups)
   - Spatial autocorrelation analysis
   - Hotspot analysis (Getis-Ord Gi*, Local Moran's I)

5. **Visualization Improvements**:
   - Time series visualizations
   - Interactive dashboards with filtering
   - Comparative visualizations across time periods

---

## 11. Conclusion

This methods report documents the comprehensive data wrangling pipeline implemented for the NYC Airbnb analysis project. The methodology encompasses data cleaning, spatial integration, statistical modeling, and visualization, utilizing a multi-language approach (R, Python, SQL) to leverage the strengths of each tool. While the current model shows limited predictive power, the pipeline provides a robust foundation for future enhancements and more sophisticated analyses.

The project demonstrates best practices in data science workflows, including:
- Reproducible data processing pipelines
- Comprehensive data quality assurance
- Integration of multiple data sources
- Spatial analysis techniques
- Statistical modeling with diagnostics
- Interactive and static visualizations

Future work should focus on enhancing model performance through feature engineering, advanced modeling techniques, and improved data quality measures.

---

## References

1. **Inside Airbnb**: http://insideairbnb.com/get-the-data.html
2. **U.S. Census Bureau ACS**: https://www.census.gov/data/developers/data-sets/acs-5year.html
3. **Nominatim (OpenStreetMap)**: https://nominatim.openstreetmap.org/
4. **R tidyverse**: https://www.tidyverse.org/
5. **sf package**: https://r-spatial.github.io/sf/
6. **tidycensus package**: https://walker-data.com/tidycensus/

---

*Document Version: 1.0*  
*Last Updated: 2025-01-XX*  
*Project: QBS181 Data Wrangling - NYC Airbnb Analysis*

