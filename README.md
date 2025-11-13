# QBS181 NYC Airbnb Data Wrangling Project

This document provides a comprehensive, professional English-language guide for fully reproducing the end-to-end data wrangling, spatial integration, modeling, and visualization pipeline implemented in this repository. New collaborators and evaluators can follow the steps below to recreate our workflow from raw inputs
to final deliverables.

---

## Repository Overview

```text
QBS181-Data-Wrangling-Project-main/
├── Analysis.Rmd                     # Modeling and diagnostics
├── Final Analysis Data.Rmd          # Spatial join and analytics base table creation
├── NY-ACS.Rmd                       # ACS (American Community Survey) data ingestion
├── vis_data.Rmd                     # Visualization and exploratory analysis
├── SQL_Commands.sql                 # MySQL scripts for wide-table construction/cleansing
├── dw_data_approval (3).pdf         # Data-usage approval documentation
├── Data/                            # Input and output data assets (see data dictionary)
├── Data Cleaning/                   # Cleaning scripts and intermediate artifacts
│   ├── Data Cleaning.Rmd
│   ├── df_cleaned_second_geo.py
│   └── Data/
│       ├── Airbnb_Open_Data_cleaned_first.csv
│       ├── df_cleaned_second.csv
│       └── airbnb_nyc_final_clean.csv
└── README_en.md
```

---

## Quick Reproduction Roadmap

| Stage | Script / File | Key Outputs |
| ----- | ------------- | ----------- |
| 0. Environment setup | - | R, Python, MySQL, and supporting dependencies installed |
| 1. Raw Airbnb cleaning | `Data Cleaning/Data Cleaning.Rmd` | `Airbnb_Open_Data_cleaned_first.csv`, `df_cleaned_second.csv` |
| 2. Reverse geocoding | `Data Cleaning/df_cleaned_second_geo.py` | `airbnb_nyc_final_clean.csv` |
| 3. ACS socio-economic data ingestion | `NY-ACS.Rmd` | `Data/nyc_acs_data.csv` |
| 4. Spatial integration & analytics table | `Final Analysis Data.Rmd` + `SQL_Commands.sql` | `final_analytics_base_table.csv`, `final_data.csv` |
| 5. Modeling & diagnostics | `Analysis.Rmd` | Regression output, `model_data.csv` |
| 6. Visualization & dashboarding | `vis_data.Rmd` | HTML visuals, interactive dashboards |

Detailed instructions for each stage are provided below.

---

## Environment & Dependencies

### Operating System
- Windows 10/11 (example path: `D:\2025_Fall\datawrang\group\QBS181-Data-Wrangling-Project-main`).
- macOS or Linux are also supported; adjust file paths and package installation commands accordingly.

### R Toolchain
- R version 4.3 or later is recommended, ideally with RStudio (or Positron/Quarto IDEs).
- Required R packages (installation prompts appear when knitting):
  `tidyverse`, `janitor`, `skimr`, `lubridate`, `sf`, `tmap`, `plotly`, `knitr`, `car`, `DBI`, `RMySQL`, `tidycensus`, `tigris`, `maptiles`, `tidyterra`, `leaflet`, `gridExtra`, `forcats`, `viridis`, `hrbrthemes`.
- In institutional networks, set a stable CRAN mirror to avoid timeouts.

### Python Environment (Reverse Geocoding)
- Python 3.9+.
- Suggested virtual environment setup:
  ```bash
  pip install pandas geopy
  ```
- Reverse geocoding uses the Nominatim API. Respect the service terms (custom `user_agent`, low request frequency).

### Database
- MySQL 8.0+ or MariaDB 10.5+.
- Ensure `LOAD DATA LOCAL INFILE` and `SELECT ... INTO OUTFILE` permissions.
- Default database name: `qbs181` (update scripts if you choose another name).
- Enable `local_infile=1` in MySQL configuration (Windows: `my.ini`).

### External Resources
- **Census API Key**: apply at https://api.census.gov/data/key_signup.html.
- **Geospatial boundaries**: `neighbourhoods.geojson` is required for certain maps; download from NYC Open Data or Inside Airbnb.
- To knit PDF outputs, install TinyTeX or another LaTeX distribution.

---

## Step-by-Step Reproduction Guide

### 0. Working Directory Setup
1. Clone or download the repository.
2. In RStudio, set the working directory to the project root:
   ```r
   setwd("D:/2025_Fall/datawrang/group/QBS181-Data-Wrangling-Project-main")
   ```
3. Confirm that `Data/` and `Data Cleaning/Data/` directories are writable.

### 1. Clean Raw Airbnb Data
- **File**: `Airbnb_Open_Data.xlsx` and `Data Cleaning/Data Cleaning.Rmd`
- **Objective**: harmonize the Airbnb dataset (from `Airbnb_Open_Data.xlsx` or `Airbnb_Open_Data_cleaned_first.csv`), fix types, and handle missing values.

Key tasks:

1. Remove Redundant Columns. Delete columns with minimal information: license, country, and country code.
2. Remove Duplicate Rows.Select the entire dataset → Data → Remove Duplicates (541 records removed).
3. Fill Missing Text Values. In NAME and host name columns, use Find and Replace: Find: (leave blank). Replace with: blank
4. Standardize Categorical Variables. Correct typos in neighbourhood group: manhatan → Manhattan, brookln → Brooklyn
5. Clean Price and Service Fee Columns. Use Find and Replace to remove non-numeric symbols: Replace $ and , with nothing. Repeat for service fee.
6. Preliminary Numeric and Date Validation. Sort minimum nights ascending → inspect for negative values (e.g., –1) and manually correct to 1 or 0.
7. Open `Data Cleaning.Rmd` in RStudio and run all chunks sequentially.
8. Operations performed include:
   - `janitor::clean_names()` for standardized column names.
   - Numeric casting for price-related attributes.
   - Median imputation for `reviews_per_month` and `availability_365`.
   - Date normalization for `last_review`, substituting out-of-range values with a median reference date.
   - Boundary enforcement on `minimum_nights` (1–365) to eliminate outliers.
9. Outputs (saved under `Data Cleaning/Data/`): `Airbnb_Open_Data_cleaned_first.csv` and `df_cleaned_second.csv`.

For alternative geographies or vintages, replace the raw file while preserving column semantics.

### 2. Augment with Reverse Geocoding
- **Script**: `Data Cleaning/df_cleaned_second_geo.py`
- **Objective**: back-fill missing `neighbourhood_group`/`neighbourhood` values using latitude and longitude.

Command-line execution:
```cmd
cd /d D:\2025_Fall\datawrang\group\QBS181-Data-Wrangling-Project-main\Data Cleaning
python df_cleaned_second_geo.py
```

The script reads `df_cleaned_second.csv` and outputs `airbnb_nyc_final_clean.csv`. Built-in retry logic handles API timeouts. If failures persist, rerun later or intervene manually.

### 3. Retrieve ACS Socioeconomic Data
- **File**: `NY-ACS.Rmd`
- **Objective**: extract ZIP Code Tabulation Area (ZCTA) level indicators for NYC from the ACS 5-year dataset.

Workflow:
1. Register your Census API key within R:
   ```r
tidycensus::census_api_key("YOUR_KEY", install = TRUE, overwrite = TRUE)
   ```
2. Run the R Markdown file to:
   - Download ZCTA metrics (`median_income`, `population`, `median_rent`) with `tidycensus::get_acs()`.
   - Obtain NYC county geometries via `tigris::counties()`.
   - Spatially intersect ZCTAs with NYC boundaries using `sf::st_join()`.
3. Save the resulting dataset as `Data/nyc_acs_data.csv` for downstream consumption.

### 4. Spatial Join & Analytics Base Table Construction
- **Files**: `Final Analysis Data.Rmd`, `SQL_Commands.sql`
- **Objective**: combine Airbnb listings with ACS indicators, yielding modeling-ready tables.

**Step A: R-based spatial join and reshaping**
1. Run `Final Analysis Data.Rmd`, ensuring `airbnb_nyc_final_clean.csv` and `nyc_acs_data` are accessible.
2. Major steps:
   - Convert Airbnb listings to an `sf` point object (`st_as_sf`).
   - Align ACS geometry to WGS84 (`st_transform` to EPSG:4326).
   - Spatially join listings with ACS metrics (`st_join`).
   - Pivot ACS variables to wide format (`pivot_wider`).
3. Export outputs to `Data/final_analytics_base_table.csv`, `Data/final_analytics_base_table_wide.csv`, and `Data/final_data.csv` (the latter after column renaming and cleansing).

**Step B: SQL-based refinement**
1. Connect to MySQL and select the `qbs181` database:
   ```sql
   CREATE DATABASE IF NOT EXISTS qbs181;
   USE qbs181;
   ```
2. Execute `SQL_Commands.sql` (edit file paths as needed):
   ```bash
   mysql -u <username> -p --local-infile=1 qbs181 < SQL_Commands.sql
   ```
3. The script:
   - Creates `final_analytics_base_table` and ingests the CSV.
   - Aggregates ACS variables into `final_analytics_base_table_wide`.
   - Strips line breaks and special characters, producing `final_analytics_base_table_wide_clean.csv`.
4. If `SELECT ... INTO OUTFILE` permissions are restricted, export via R (`dbGetQuery` + `write_csv`).

### 5. Modeling & Diagnostics
- **File**: `Analysis.Rmd`
- **Objective**: run a multiple linear regression on log-transformed prices, produce diagnostics, and generate thematic maps.

Procedure:
1. Confirm `final_data` is available (either in MySQL or as `Data/final_data.csv`).
2. Update `dbConnect()` credentials to reflect your local environment.
3. Run the notebook to:
   - Extract modeling data (`model_data.csv`).
   - Fit a regression model on `log_price` with neighborhood, room type, and socioeconomic covariates.
   - Execute `run_model_diagnostics()` (custom function) for VIF and residual plots.
   - Produce maps such as `plot_income_map()` and `plot_airbnb_prices()`.

### 6. Visualization & Dashboarding
- **File**: `vis_data.Rmd`
- **Objective**: deliver static and interactive visual analytics for stakeholders.

Execution tips:
1. Ensure `airbnb_nyc_clean.csv` exists (copy/rename `airbnb_nyc_final_clean.csv` if necessary).
2. Knit or run all chunks to create:
   - Borough/room-type distributions and top-neighborhood charts.
   - Tile-based price scatterplots (`maptiles`) and interactive `leaflet` maps.
   - `plotly` dashboards for room-type exploration.
   - Minimum nights distributions and other supporting visuals.
3. Provide `neighbourhoods.geojson` if choropleth maps are required; place it in the project root.

### 7. Final QA & Archival
Verify the following core deliverables are present and up to date:
- `Data/airbnb_nyc_final_clean.csv`
- `Data/final_data.csv`
- `Data/model_data.csv`
- Knit outputs (PDF/HTML) for analysis and visualization reports

Store logs, configuration files, and environment notes for review and future iterations.

---

## Data Dictionary & File Descriptions

| Path | Description | Generated By |
| ---- | ----------- | ------------ |
| `Data/Airbnb_Open_Data.xlsx` | Original Airbnb NYC dataset (2019) | External source (manual download) |
| `Data Cleaning/Data/Airbnb_Open_Data_cleaned_first.csv` | Initial cleaned version | `Data Cleaning.Rmd` |
| `Data Cleaning/Data/df_cleaned_second.csv` | Post-imputation cleaned dataset | `Data Cleaning.Rmd` |
| `Data Cleaning/Data/airbnb_nyc_final_clean.csv` | Geocoding-enhanced listings | `df_cleaned_second_geo.py` |
| `Data/nyc_acs_data.csv` | NYC ACS metrics (ZCTA-level) | `NY-ACS.Rmd` |
| `Data/final_analytics_base_table.csv` | Spatially joined long table | `Final Analysis Data.Rmd` |
| `Data/final_analytics_base_table_wide.csv` | Pivoted wide table (pre-cleaning) | `Final Analysis Data.Rmd` |
| `Data/final_analytics_base_table_wide_clean.csv` | Wide table with sanitized text fields | `SQL_Commands.sql` |
| `Data/final_data.csv` | Modeling-ready dataset | `Final Analysis Data.Rmd` |
| `Data/model_data.csv` | Regression feature set | `Analysis.Rmd` |

> Adjust file paths or names consistently across scripts if you customize storage locations.

---

## Troubleshooting Guide

- **R package installation failures**: switch to a reliable CRAN mirror or run `options(repos = "https://cloud.r-project.org")`.
- **Installation issues with `sf`, `tigris`, or geospatial dependencies**: Windows users should install Rtools and GDAL/GEOS (OSGeo4W); macOS users should install Xcode Command Line Tools and use Homebrew (`brew install gdal geos proj`).
- **MySQL import/export errors**: enable `local_infile`, ensure target directories exist and are writable, and verify no restrictive antivirus policies are blocking file operations.
- **Nominatim rate limits/timeouts**: leverage the script’s retry logic, throttle requests, or batch the workload.
- **Census API throttling**: cache `nyc_acs_data.csv` to prevent repeated calls during development.
- **Path encoding or whitespace issues**: prefer ASCII-only, whitespace-free directory paths or apply `normalizePath()` in R.

---

## Acknowledgements

- [Inside Airbnb](http://insideairbnb.com/get-the-data.html): primary data source for NYC listings.
- [US Census Bureau ACS](https://www.census.gov/data/developers/data-sets/acs-5year.html): socioeconomic data.
- [Nominatim (OpenStreetMap)](https://nominatim.openstreetmap.org/): reverse geocoding API.
- R community ecosystems: tidyverse, sf, leaflet, plotly, and related packages.

Feedback, issues, or enhancement proposals are welcome. Please open an issue or submit a pull request to help improve the reproducibility and robustness of this project.


