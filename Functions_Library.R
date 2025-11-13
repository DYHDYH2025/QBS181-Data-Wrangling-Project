################################################################################
# Custom Functions Library for QBS181 Data Wrangling Project
#
# This file contains all custom functions used in the project.
# Usage: source("Functions_Library.R")
#
# Function Categories:
#   1. Data Cleaning Functions
#   2. Visualization Functions
#   3. Modeling Functions
#   4. Spatial Analysis Functions
#   5. Utility Functions
#
# Last Updated: 2025-01-XX
################################################################################

# ==============================================================================
# 1. Data Cleaning Functions
# ==============================================================================

#' Fill missing values with median
#'
#' @description Replace missing values in specified numeric columns using the median.
#' @param data A data frame.
#' @param cols A vector of column names to process (default: reviews_per_month, availability_365).
#' @return A cleaned data frame.
#' @examples
#' df <- handle_missing_values(df, cols = c("reviews_per_month", "availability_365"))
handle_missing_values <- function(data, cols = c("reviews_per_month", "availability_365")) {
  for (col in cols) {
    if (col %in% names(data)) {
      median_val <- median(data[[col]], na.rm = TRUE)
      data[[col]] <- replace_na(data[[col]], median_val)
    }
  }
  return(data)
}

#' Clean and standardize a date column
#'
#' @description Convert a date column to standard format and handle invalid values.
#' @param data A data frame.
#' @param date_col Column name of the date field.
#' @param date_limit Upper bound for allowed dates (default "2021-01-01").
#' @return A cleaned data frame.
#' @examples
#' df <- clean_date_column(df, date_col = "last_review")
clean_date_column <- function(data, date_col = "last_review", date_limit = "2021-01-01") {
  if (!require(lubridate, quietly = TRUE)) stop("Package 'lubridate' is required.")
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")
  if (!require(rlang, quietly = TRUE)) stop("Package 'rlang' is required.")

  if (!date_col %in% names(data)) {
    warning(paste("Column", date_col, "not found in data"))
    return(data)
  }

  data[[date_col]] <- mdy(data[[date_col]])

  date_limit_date <- as.Date(date_limit)
  valid_dates <- data[[date_col]][!is.na(data[[date_col]]) &
                                    data[[date_col]] <= date_limit_date]
  median_date <- median(valid_dates, na.rm = TRUE)

  data <- data %>%
    mutate(!!sym(date_col) := if_else(
      is.na(!!sym(date_col)) | !!sym(date_col) > date_limit_date,
      median_date,
      !!sym(date_col)
    ))

  return(data)
}

#' Clean minimum_nights column
#'
#' @description Constrain minimum_nights to a reasonable range (1–365).
#' @param data A data frame.
#' @param min_val Minimum allowed value.
#' @param max_val Maximum allowed value.
#' @return A cleaned data frame.
#' @examples
#' df <- clean_minimum_nights(df)
clean_minimum_nights <- function(data, min_val = 1, max_val = 365) {
  if (!"minimum_nights" %in% names(data)) {
    warning("Column 'minimum_nights' not found in data")
    return(data)
  }

  data <- data %>%
    mutate(
      minimum_nights = case_when(
        minimum_nights <= 0 ~ min_val,
        minimum_nights > max_val ~ max_val,
        TRUE ~ minimum_nights
      )
    )

  return(data)
}

#' Clean Airbnb raw dataset
#'
#' @description Perform full cleaning for Airbnb data: standardize names, convert types, fill missing values, etc.
#' @param data Airbnb data frame.
#' @param file_path Optional CSV path (if reading from file).
#' @return A cleaned data frame.
#' @examples
#' df_cleaned <- clean_airbnb_data(raw_data)
clean_airbnb_data <- function(data = NULL, file_path = NULL) {
  if (!require(tidyverse, quietly = TRUE)) stop("Package 'tidyverse' is required.")
  if (!require(janitor, quietly = TRUE)) stop("Package 'janitor' is required.")
  if (!require(lubridate, quietly = TRUE)) stop("Package 'lubridate' is required.")

  if (!is.null(file_path)) {
    data <- read_csv(file_path)
  }

  if (is.null(data)) stop("Either 'data' or 'file_path' must be provided.")

  data <- data %>% clean_names()

  data <- data %>%
    mutate(
      price = as.numeric(price),
      service_fee = as.numeric(service_fee)
    )

  data <- handle_missing_values(data)
  data <- clean_date_column(data, date_col = "last_review")
  data <- clean_minimum_nights(data)

  return(data)
}

# ==============================================================================
# 2. Visualization Functions
# ==============================================================================

#' Plot median income map for NYC ZIP codes
#'
#' @description Generate a choropleth map showing median household income by ZIP code.
#' @param nyc_acs_wide sf object containing ACS data and geometry.
#' @param income_col Income column name.
#' @param title Title of the plot.
#' @return A ggplot object.
#' @examples
#' plot_income_map(nyc_acs_wide)
plot_income_map <- function(nyc_acs_wide,
                            income_col = "median_income",
                            title = "Median Household Income by ZIP Code (NYC, 2020)") {
  if (!require(ggplot2, quietly = TRUE)) stop("Package 'ggplot2' is required.")
  if (!require(sf, quietly = TRUE)) stop("Package 'sf' is required.")
  if (!require(viridis, quietly = TRUE)) stop("Package 'viridis' is required.")
  if (!require(scales, quietly = TRUE)) stop("Package 'scales' is required.")

  ggplot(nyc_acs_wide) +
    geom_sf(aes(fill = !!sym(income_col)), color = NA) +
    scale_fill_viridis_c(
      option = "plasma",
      labels = dollar,
      na.value = "grey90"
    ) +
    labs(
      title = title,
      fill = "Median Income ($)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      legend.position = "right"
    )
}

#' Plot Airbnb price distribution scatter map
#'
#' @description Plot Airbnb listings on a map colored by price.
#' @param model_data Data frame with lat, long, and price_numeric.
#' @param max_price Maximum price to display.
#' @param title Plot title.
#' @return A ggplot object.
#' @examples
#' plot_airbnb_prices(model_data)
plot_airbnb_prices <- function(model_data,
                               max_price = 1000,
                               title = "NYC Airbnb Price Distribution (< $1000 Listings)") {
  if (!require(ggplot2, quietly = TRUE)) stop("Package 'ggplot2' is required.")
  if (!require(viridis, quietly = TRUE)) stop("Package 'viridis' is required.")
  if (!require(scales, quietly = TRUE)) stop("Package 'scales' is required.")

  ggplot(data = model_data %>% filter(price_numeric < max_price)) +
    geom_point(
      aes(x = long, y = lat, color = price_numeric),
      size = 0.7,
      alpha = 0.6
    ) +
    scale_color_viridis_c(
      option = "inferno",
      trans = "log",
      name = "Price (log scale)",
      labels = dollar
    ) +
    coord_equal() +
    labs(
      title = title,
      x = "Longitude",
      y = "Latitude"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5),
      legend.position = "right"
    )
}

#' Plot borough distribution
#'
#' @description Create a bar chart showing the number of listings per borough.
#' @param data Data frame containing neighbourhood_group.
#' @param title Plot title.
#' @return A ggplot object.
#' @examples
#' plot_borough_distribution(data_cleaned)
plot_borough_distribution <- function(data,
                                      title = "NYC Airbnb Listing Count by Borough") {
  if (!require(ggplot2, quietly = TRUE)) stop("Package 'ggplot2' is required.")
  if (!require(forcats, quietly = TRUE)) stop("Package 'forcats' is required.")
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")

  borough_data <- data %>%
    count(neighbourhood_group, name = "n") %>%
    mutate(
      neighbourhood_group = fct_reorder(neighbourhood_group, n, .desc = TRUE)
    )

  ggplot(borough_data, aes(x = neighbourhood_group, y = n)) +
    geom_col(fill = "#56B4E9") +
    labs(
      title = title,
      subtitle = "Manhattan and Brooklyn are the dominant boroughs",
      x = "Borough",
      y = "Number of Listings",
      caption = "Source: NYC Airbnb Data (2019)"
    ) +
    theme_minimal() +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}

#' Plot room type distribution
#'
#' @description Plot room type distribution (overall or by borough).
#' @param data Data frame containing room_type.
#' @param by_borough Whether to group by borough.
#' @param title Plot title.
#' @return A ggplot object.
#' @examples
#' plot_room_type_distribution(data_cleaned)
#' plot_room_type_distribution(data_cleaned, by_borough = TRUE)
plot_room_type_distribution <- function(data,
                                        by_borough = FALSE,
                                        title = "Room Type Distribution") {
  if (!require(ggplot2, quietly = TRUE)) stop("Package 'ggplot2' is required.")
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")
  if (!require(viridis, quietly = TRUE)) stop("Package 'viridis' is required.")

  if (by_borough) {
    p <- ggplot(data, aes(x = neighbourhood_group, fill = room_type)) +
      geom_bar(position = "stack") +
      scale_fill_viridis_d(option = "cividis") +
      labs(
        title = "Room Type Composition by Borough",
        x = "Borough",
        y = "Number of Listings",
        fill = "Room Type"
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
  } else {
    p <- ggplot(data, aes(x = room_type)) +
      geom_bar(fill = "darkorange") +
      labs(
        title = title,
        x = "Room Type",
        y = "Count"
      ) +
      theme_minimal()
  }

  return(p)
}

# ==============================================================================
# 3. Modeling Functions
# ==============================================================================

#' Run regression diagnostics
#'
#' @description Compute VIF and generate diagnostic plots.
#' @param model Linear model object.
#' @param plot_residuals Whether to plot residual diagnostics.
#' @return None. Prints output.
#' @examples
#' run_model_diagnostics(model)
run_model_diagnostics <- function(model, plot_residuals = TRUE) {
  if (!require(car, quietly = TRUE)) stop("Package 'car' is required.")

  cat("--- VIF (Multicollinearity) ---\n")
  if (length(coef(model)) > 2) {
    print(car::vif(model))
  } else {
    cat("The model has too few variables to calculate VIF.\n")
  }

  if (plot_residuals) {
    cat("\n--- Residual Plots ---\n")
    par(mfrow = c(2, 2))
    plot(model)
    par(mfrow = c(1, 1))
  }
}

#' Prepare modeling dataset from database or CSV
#'
#' @description Load modeling dataset from MySQL or CSV file.
#' @param source "database" or "csv".
#' @param db_connection DBI connection object.
#' @param csv_path Path to CSV file.
#' @param table_name Table name in database.
#' @return A modeling data frame.
#' @examples
#' model_data <- prepare_model_data("csv", "data/model_data.csv")
prepare_model_data <- function(source = "database",
                               db_connection = NULL,
                               csv_path = "data/model_data.csv",
                               table_name = "final_data") {
  if (source == "database") {
    if (!require(DBI, quietly = TRUE)) stop("Package 'DBI' is required.")
    if (is.null(db_connection)) stop("Database connection required.")

    query <- paste("
      SELECT
        id,
        neighbourhood_group,
        cancellation_policy,
        room_type,
        construction_year,
        price AS price_numeric,
        LOG(price) AS log_price,
        minimum_nights,
        number_of_reviews,
        availability_365,
        service_fee,
        reviews_per_month,
        GEOID_x,
        median_income,
        population,
        median_rent
      FROM", table_name, "
      WHERE price > 0
        AND median_income IS NOT NULL
        AND room_type IS NOT NULL
        AND neighbourhood_group IS NOT NULL;
    ")

    model_data <- dbGetQuery(db_connection, query)

  } else if (source == "csv") {
    if (!require(readr, quietly = TRUE)) stop("Package 'readr' is required.")
    model_data <- read_csv(csv_path, show_col_types = FALSE)
  } else {
    stop("source must be either 'database' or 'csv'")
  }

  return(model_data)
}

# ==============================================================================
# 4. Spatial Analysis Functions
# ==============================================================================

#' Perform spatial join between Airbnb points and ACS polygons
#'
#' @description Join Airbnb point data with ACS region data via spatial join.
#' @param airbnb_data Airbnb data frame with lat/long.
#' @param acs_data ACS sf object.
#' @param crs Coordinate reference system.
#' @param drop_geometry Whether to drop geometry.
#' @return Joined data frame.
#' @examples
#' joined <- spatial_join_airbnb_acs(df, acs)
spatial_join_airbnb_acs <- function(airbnb_data,
                                    acs_data,
                                    crs = 4326,
                                    drop_geometry = TRUE) {
  if (!require(sf, quietly = TRUE)) stop("Package 'sf' is required.")
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")

  airbnb_data <- airbnb_data %>%
    filter(!is.na(long) & !is.na(lat))

  airbnb_sf <- airbnb_data %>%
    st_as_sf(coords = c("long", "lat"), crs = crs)

  if (st_crs(acs_data)$epsg != crs) {
    acs_data <- st_transform(acs_data, crs = crs)
  }

  joined_data <- st_join(airbnb_sf, acs_data, join = st_intersects)

  if (drop_geometry) {
    joined_data <- joined_data %>%
      st_drop_geometry() %>%
      as.data.frame()
  }

  return(joined_data)
}

#' Convert long-format ACS data into wide format
#'
#' @description Convert ACS long data with variable/estimate into wide-format table.
#' @param long_data Long-format ACS table.
#' @param id_cols ID columns.
#' @param value_fn Aggregation function.
#' @return A wide-format data frame.
#' @examples
#' wide <- create_wide_table(long_data, id_cols = c("id", "GEOID"))
create_wide_table <- function(long_data,
                              id_cols = "id",
                              value_fn = mean) {
  if (!require(tidyr, quietly = TRUE)) stop("Package 'tidyr' is required.")
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")

  wide_data <- long_data %>%
    pivot_wider(
      names_from = variable,
      values_from = estimate,
      id_cols = all_of(id_cols),
      values_fn = value_fn
    )

  return(wide_data)
}

# ==============================================================================
# 5. Utility Functions
# ==============================================================================

#' Check data quality
#'
#' @description Check missing values, duplicates, and basic structure.
#' @param data A data frame.
#' @param print_summary Whether to print summary.
#' @return List of data quality metrics.
#' @examples
#' check_data_quality(df)
check_data_quality <- function(data, print_summary = TRUE) {
  if (!require(dplyr, quietly = TRUE)) stop("Package 'dplyr' is required.")

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

#' Load all required project packages
#'
#' @description Check and install missing packages if needed.
#' @param install_missing Whether to install missing packages.
#' @return None.
#' @examples
#' load_project_packages()
load_project_packages <- function(install_missing = TRUE) {
  required_packages <- c(
    "tidyverse", "janitor", "skimr", "lubridate",
    "sf", "tmap", "plotly", "knitr", "car",
    "DBI", "RMySQL", "tidycensus", "tigris",
    "maptiles", "tidyterra", "leaflet", "gridExtra",
    "forcats", "viridis", "hrbrthemes", "scales"
  )

  for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      if (install_missing) {
        cat("Installing", pkg, "...\n")
        install.packages(pkg)
        library(pkg, character.only = TRUE)
      } else {
        warning(paste("Package", pkg, "is not installed."))
      }
    }
  }

  cat("All required packages are loaded.\n")
}

# ==============================================================================
# Load completion message
# ==============================================================================

cat("Functions Library loaded successfully!\n")
cat("Available functions:\n")
cat("  - Data Cleaning: clean_airbnb_data, handle_missing_values, clean_date_column, clean_minimum_nights\n")
cat("  - Visualization: plot_income_map, plot_airbnb_prices, plot_borough_distribution, plot_room_type_distribution\n")
cat("  - Modeling: run_model_diagnostics, prepare_model_data\n")
cat("  - Spatial Analysis: spatial_join_airbnb_acs, create_wide_table\n")
cat("  - Utilities: check_data_quality, load_project_packages\n")
cat("\nUse ?function_name to view documentation.\n")
