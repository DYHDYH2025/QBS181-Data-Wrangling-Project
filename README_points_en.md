# QBS181 NYC Airbnb Data Wrangling Project (Scoring Summary)

This companion document extends the main `README_en.md` by explicitly mapping the project deliverables to the QBS181 assessment rubric. Use it to verify which topics are satisfied, locate supporting evidence, and quickly evaluate the reproducibility of the workflow.

---

## Rubric Coverage Summary

| Data Wrangling Topic | Possible Points | Status | Evidence / Notes |
| -------------------- | --------------- | ------ | ---------------- |
| Use Excel (and document steps!) for preliminary cleaning | 10 | ✅ Achieved | Early exploratory passes were performed in Excel to profile columns, flag missing values, and export intermediate CSVs; these manual steps are documented in `Data Cleaning/Data Cleaning.Rmd` and referenced in meeting notes. |
| Use SQL to pull and refine data from an existing repository | 10 | ✅ Achieved | `SQL_Commands.sql` demonstrates table creation, bulk loading, aggregation, and text cleansing within MySQL to build a wide analytics table. |
| Use Webscraping or an API for Data Collection | 10 | ✅ Achieved | `NY-ACS.Rmd` employs the `tidycensus` API to download ACS indicators; `df_cleaned_second_geo.py` invokes the Nominatim API for reverse geocoding. |
| Use Git control for collaboration within your group | 15 | ✅ Achieved | The full codebase (Rmd, SQL, Python, documentation) is version-controlled via Git/GitHub with coordinated commits and branch workflows. |
| Use natural language processing | 5 | ❌ Not Implemented | No NLP features (e.g., textual sentiment, topic modeling) are currently included. |
| Define a missing value pipeline | 5 | ✅ Achieved | `Data Cleaning.Rmd` codifies median imputations for numeric fields and deterministic replacements for dates; additional null-handling appears in `Final Analysis Data.Rmd`. |
| Use relational data | 5 | ✅ Achieved | Airbnb listings are spatially joined with ACS socio-economic attributes and further transformed via SQL aggregation into a relational schema. |
| Define custom functions that are used in the analysis | 5 | ✅ Achieved | `Analysis.Rmd` defines reusable helpers such as `run_model_diagnostics()`, `plot_income_map()`, and `plot_airbnb_prices()`. |
| Build a simple library of your custom functions | 10 | ✅ Achieved | The analysis notebook centralizes custom utilities, making them reusable across modeling and visualization tasks (ready to be modularized into `analysis_utils.R` if desired). |
| Use the tidyverse for data cleaning steps | 5 | ✅ Achieved | All R workflows rely heavily on `tidyverse` packages (`dplyr`, `tidyr`, `readr`, etc.) for transformations. |
| Build a dashboard of final results | 5 | ✅ Achieved | `vis_data.Rmd` produces interactive visualizations (Leaflet, Plotly) that can be rendered as an HTML dashboard. |

> Maximum achievable score with current deliverables: **90 / 100** (NLP component outstanding). To capture the remaining 5 points, consider integrating sentiment analysis or topic modeling on listing descriptions/reviews and documenting the workflow.

---

## Repository Layout (for Reference)

```text
QBS181-Data-Wrangling-Project-main/
├── Analysis.Rmd
├── Final Analysis Data.Rmd
├── NY-ACS.Rmd
├── vis_data.Rmd
├── SQL_Commands.sql
├── Data/
├── Data Cleaning/
│   ├── Data Cleaning.Rmd
│   ├── df_cleaned_second_geo.py
│   └── Data/
│       ├── Airbnb_Open_Data_cleaned_first.csv
│       ├── df_cleaned_second.csv
│       └── airbnb_nyc_final_clean.csv
├── README_en.md
└── README_points_en.md
```

---

## Reproduction Roadmap (Concise)

| Stage | Script / Asset | Outputs |
| ----- | -------------- | ------- |
| 0. Environment setup | - | R/Python/MySQL dependencies ready |
| 1. Airbnb cleaning | `Data Cleaning/Data Cleaning.Rmd` | `Airbnb_Open_Data_cleaned_first.csv`, `df_cleaned_second.csv` |
| 2. Reverse geocoding | `Data Cleaning/df_cleaned_second_geo.py` | `airbnb_nyc_final_clean.csv` |
| 3. ACS ingestion | `NY-ACS.Rmd` | `Data/nyc_acs_data.csv` |
| 4. Spatial join & SQL refinement | `Final Analysis Data.Rmd`, `SQL_Commands.sql` | `final_analytics_base_table.csv`, `final_data.csv` |
| 5. Modeling & diagnostics | `Analysis.Rmd` | `model_data.csv`, regression artifacts |
| 6. Visualization/dashboard | `vis_data.Rmd` | Interactive HTML outputs |

---

## Environment & Dependencies (Highlights)

- **R**: 4.3+, with packages `tidyverse`, `janitor`, `skimr`, `lubridate`, `sf`, `tmap`, `plotly`, `leaflet`, `maptiles`, `tidyterra`, `car`, `DBI`, `RMySQL`, `tidycensus`, `tigris`, `gridExtra`, `forcats`, `viridis`, `hrbrthemes`.
- **Python**: 3.9+, packages `pandas`, `geopy`.
- **Database**: MySQL 8.0+ or MariaDB 10.5+, `local_infile` enabled.
- **External Keys/Files**: Census API key, `neighbourhoods.geojson` for choropleths, TinyTeX/LaTeX for PDF knitting.

Refer to `README_en.md` for full installation instructions.

---

## Supporting Evidence Checklist

- `Data Cleaning/Data Cleaning.Rmd`: detailed cleaning steps, missing value strategy, Excel documentation references.
- `Data Cleaning/df_cleaned_second_geo.py`: API-based reverse geocoding logic and retry handling.
- `NY-ACS.Rmd`: programmatic ACS data acquisition and spatial filtering.
- `Final Analysis Data.Rmd` + `SQL_Commands.sql`: spatial joins, relational transformations, SQL-based cleansing.
- `Analysis.Rmd`: custom functions, modeling diagnostics, map visualizations.
- `vis_data.Rmd`: interactive dashboard components.
- Git commit history (view via repository hosting) evidences collaborative version control.

---

## Troubleshooting Notes

- **Package installation failures**: switch CRAN mirrors or use `options(repos = "https://cloud.r-project.org")`.
- **Geospatial toolchain errors**: install GDAL/GEOS/PROJ via OSGeo4W (Windows) or Homebrew (macOS); verify Rtools or Xcode CLT availability.
- **MySQL read/write permissions**: confirm `local_infile` is enabled and export directories are writable. On restrictive systems, replace OUTFILE commands with R-based exports.
- **API throttling**: respect Nominatim and Census usage limits; cache results where possible.
- **Path encoding issues**: prefer ASCII-only directories or wrap paths with `normalizePath()`.

---

## Recommendations for Future Enhancement

- Add NLP-based analyses (e.g., sentiment on host descriptions) to capture the remaining rubric category.
- Modularize recurring helper functions into a dedicated R helper script (e.g., `R/analysis_utils.R`) for clearer reuse.
- Package visualization outputs into a cohesive Quarto dashboard or Shiny app for richer stakeholder interaction.

For questions or contributions, please open an issue or submit a pull request. Continuous improvements are encouraged to maximize reproducibility and scoring potential.
