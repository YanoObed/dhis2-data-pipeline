
# LIBRARIES
library(httr)
library(jsonlite)
library(dplyr)
library(janitor)
library(glue)
library(tidyverse)
library(cli)
library(openxlsx)
library(lubridate)
library(stringr)
library(purrr)
library(readr)


# CREDENTIALS & CONFIG

USERNAME <- Sys.getenv("DHIS2_USERNAME")
PASSWORD <- Sys.getenv("DHIS2_PASSWORD")
BASE_URL <- Sys.getenv("DHIS2_BASE_URL")

OUTPUT_DIR <- "YOUR OUTPUT DIRECTORY"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)


# HELPER FUNCTIONS
# Build hierarchy for org units (left joins to avoid losing units)
make_orgunits_hierarchy <- function(df) {
  
  facilities <- df %>%
    filter(level == 5) %>%
    select(
      id,
      name,
      code,
      parent_id,
      ownership
    ) %>%
    rename(
      facility_id = id,
      facility_name = name,
      ward_id = parent_id
    )
  
  wards <- df %>%
    filter(level == 4) %>%
    select(id, name, parent_id) %>%
    rename(
      ward_id = id,
      ward_name = name,
      sub_county_id = parent_id
    )
  
  sub_counties <- df %>%
    filter(level == 3) %>% 
    select(id, name, parent_id) %>%
    rename(
      sub_county_id = id,
      sub_county_name = name,
      county_id = parent_id
    )
  
  counties <- df %>%
    filter(level == 2) %>%
    select(id, name, parent_id) %>%
    rename(
      county_id = id,
      county_name = name,
      country_id = parent_id
    )
  
  country <- df %>%
    filter(level == 1) %>%
    select(id, name) %>%
    rename(
      country_id = id,
      country_name = name
    )
  
  facilities %>%
    left_join(wards, by = "ward_id") %>%
    left_join(sub_counties, by = "sub_county_id") %>%
    left_join(counties, by = "county_id") %>%
    left_join(country, by = "country_id") %>%
    relocate(facility_id, .before = facility_name)
}

# Generate analytics API URL
generate_api_url <- function(data_elements, org_units, start_month, end_month, outputIdScheme = "UID", include_ownership = FALSE) {
  
  base_url <- paste0(BASE_URL, "/api/analytics.csv?")
  
  data_elements_spec <- paste0("dimension=dx%3A", paste0(data_elements, collapse = "%3B"), "&")
  
  ownership_spec <- if(include_ownership) "dimension=JlW9OiK1eR4%3AAaAF5EmS1fk&" else ""
  org_units_spec <- paste0("dimension=ou%3A", paste0(org_units, collapse = "%3B"), "&")
  
  periods_vector <- seq(from = as.Date(start_month), to = as.Date(end_month), by = "month")
  periods_spec <- paste0("dimension=pe%3A", paste0(format(periods_vector, "%Y%m"), collapse = "%3B"), "&")
  
  other_params <- glue(
    "showHierarchy=false&hierarchyMeta=false&includeMetadataDetails=true&includeNumDen=false&skipRounding=false&completedOnly=false&outputIdScheme={outputIdScheme}"
  )
  
  glue(base_url, data_elements_spec, ownership_spec, org_units_spec, periods_spec, other_params)
}

# Extract data from DHIS2
extract_dhis2_data <- function(username, password, data_elements, org_units, start_month, end_month, outputIdScheme = "UID") {
  
  if(length(org_units) == 0) return(tibble(org_unit = character(), analytic = character(), period = character(), value = numeric()))
  
  api_url <- generate_api_url(data_elements, org_units, start_month, end_month, outputIdScheme)
  
  resp <- try(GET(api_url, authenticate(username, password), timeout(120)), silent = TRUE)
  
  if (inherits(resp, "try-error")) {
    cli_alert_warning(glue("Request error for {length(org_units)} org units"))
    return(tibble(org_unit = character(), analytic = character(), period = character(), value = numeric()))
  }
  
  status <- status_code(resp)
  if(!(status %in% c(200, 206))) {
    cli_alert_warning(glue("Request returned status {status} for {length(org_units)} org units"))
    return(tibble(org_unit = character(), analytic = character(), period = character(), value = numeric()))
  }
  
  content_text <- content(resp, "text", encoding = "UTF-8")
  if(nchar(content_text) == 0) {
    cli_alert_warning(glue("Empty response for {length(org_units)} org units"))
    return(tibble(org_unit = character(), analytic = character(), period = character(), value = numeric()))
  }
  
  # read CSV safely using I() for literal string
  df <- try(read_csv(I(content_text), show_col_types = FALSE), silent = TRUE)
  if(inherits(df, "try-error") || nrow(df) == 0) {
    cli_alert_warning(glue("Failed to parse CSV or no data returned for {length(org_units)} org units"))
    return(tibble(org_unit = character(), analytic = character(), period = character(), value = numeric()))
  }
  
  df %>%
    clean_names() %>%
    rename(org_unit = organisation_unit, analytic = data) %>%
    select(org_unit, analytic, period, value) %>%
    mutate(period = as.character(period))   # <- Force period to character
}

# Fetch org units
get_org_units <- function() {
  
  url <- paste0(
    BASE_URL,
    "/api/organisationUnits?",
    "fields=id,name,level,code,parent,organisationUnitGroups[id,displayName]&paging=false"
  )
  
  r <- GET(
    url,
    authenticate(USERNAME, PASSWORD),
    timeout(60)
  )
  
  stopifnot(status_code(r) == 200)
  
  x <- content(r, "text") %>%
    fromJSON()
  
  x$organisationUnits %>%
    as.data.frame()
}
# Fetch data elements
get_data_elements <- function() {
  url <- paste0(BASE_URL, "/api/dataElements?fields=id,name,shortName&paging=false")
  r <- GET(url, authenticate(USERNAME, PASSWORD), timeout(60))
  stopifnot(status_code(r) == 200)
  content(r, "text") %>% fromJSON() %>% .$dataElements %>% as.data.frame()
}

# =========================
# METADATA
org_units <- get_org_units()


# Facility Ownership lookup
# =========================
# OWNERSHIP MAPPING
# =========================

ownership_lookup <- data.frame(
  id = c(
    "AaAF5EmS1fk",
    "g58rumvciv2",
    "eT1vvFVhLHc",
    "aRxa6o8GqZN"
  ),
  ownership = c(
    "Public",
    "NGO",
    "Faith Based",
    "Private"
  )
)


org_units$ownership <- map_chr(
  org_units$organisationUnitGroups,
  function(g){
    
    if(is.null(g) || nrow(g)==0)
      return(NA_character_)
    
    
    found <- ownership_lookup$ownership[
      match(
        g$id,
        ownership_lookup$id
      )
    ]
    
    found <- found[!is.na(found)]
    
    
    if(length(found)>0)
      return(found[1])
    
    
    NA_character_
  }
)


data_elements <- get_data_elements()

org_units_cleaned <- org_units %>%
  unnest_wider(parent, names_sep="_") %>%
  make_orgunits_hierarchy() %>%
  rename(mfl_code = code) %>%
  select(
    facility_id,
    facility_name,
    ward_name,
    sub_county_name,
    county_name,
    ownership,
    mfl_code
  )

# =========================
DX <- c(
  "PgQIx7Hq1kp.wBWcFk7k1qY",   # DMPA_IM_New_clients
  "PgQIx7Hq1kp.K4WLOEhtcvC",   # DMPA_IM_Re_visits
  "NMCIxSeGpS3.wBWcFk7k1qY",   # DMPA_SC_New_clients
  "NMCIxSeGpS3.K4WLOEhtcvC",   # DMPA_SC_Re_visits
  
  "Wv02gixbRpT.DTYqflFj4uE",   # Hormonal IUD (COC 1)
  "Wv02gixbRpT.xiLt33hq7so"    # Hormonal IUD (COC 2)
)

# =========================
# BATCHING FACILITIES
BATCH_SIZE <- 50
facility_chunks <- org_units_cleaned %>%
  select(facility_id) %>%
  rowid_to_column() %>%
  mutate(batch = ceiling(rowid / BATCH_SIZE)) %>%
  group_by(batch) %>%
  group_split()

# =========================
# EXTRACT DATA
all_data <- tibble(
  org_unit = character(),
  analytic = character(),
  period = character(),
  value = numeric()
)

cat("Total batches:", length(facility_chunks), "\n")

for(i in seq_along(facility_chunks)) {
  
  chunk <- facility_chunks[[i]]
  org_units_batch <- chunk$facility_id
  
  cat(glue("Processing batch {i}/{length(facility_chunks)} with {length(org_units_batch)} facilities...\n"))
  
  batch_data <- extract_dhis2_data(
    USERNAME,
    PASSWORD,
    DX,
    org_units_batch,
    "2025-01-01",
    "2026-08-01"
  )
  
  if(nrow(batch_data) > 0) {
    all_data <- bind_rows(all_data, batch_data)
    cat(glue("Batch {i} rows downloaded: {nrow(batch_data)}\n"))
  } else {
    cli_alert_warning(glue("Batch {i} returned 0 rows"))
  }
  
  Sys.sleep(2)
}

cat("Download complete. Total rows:", nrow(all_data), "\n")



#MASTER LIST
final_data <- all_data %>%
  mutate(period = ym(period)) %>%
  left_join(
    org_units_cleaned,
    by = c("org_unit" = "facility_id")
  ) %>%
  mutate(
    indicator_name = case_when(
      analytic == "PgQIx7Hq1kp.wBWcFk7k1qY" ~ "DMPA_IM_New_clients",
      analytic == "PgQIx7Hq1kp.K4WLOEhtcvC" ~ "DMPA_IM_Re_visits",
      analytic == "NMCIxSeGpS3.wBWcFk7k1qY" ~ "DMPA_SC_New_clients",
      analytic == "NMCIxSeGpS3.K4WLOEhtcvC" ~ "DMPA_SC_Re_visits",
      
      analytic == "Wv02gixbRpT.DTYqflFj4uE" ~ "Hormonal_IUD",
      analytic == "Wv02gixbRpT.xiLt33hq7so" ~ "Hormonal_IUD",
      
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(indicator_name)) %>%
  group_by(
    county_name,
    sub_county_name,
    facility_name,
    org_unit,
    ownership,
    period,
    indicator_name
  ) %>%
  summarise(
    value = sum(as.numeric(value), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    id_cols = c(
      county_name,
      sub_county_name,
      facility_name,
      org_unit,
      ownership,
      period
    ),
    names_from = indicator_name,
    values_from = value
  )

names(final_data)

table(final_data$ownership, useNA="always")

output_file <- file.path(OUTPUT_DIR, paste0("DHIS2_FP_Injections_", Sys.Date(), ".xlsx"))
write.xlsx(final_data, output_file, overwrite = TRUE)
cli_alert_success(glue("SUCCESS: File saved to {output_file}"))
