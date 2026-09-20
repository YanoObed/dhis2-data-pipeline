# DHIS2 Data Pipeline – KHIS Family Planning

An R-based data pipeline for extracting, transforming, aggregating, and exporting family planning service-delivery data from the **Kenya Health Information System (KHIS) / DHIS2 Analytics API**.

The pipeline retrieves facility-level data, builds the health-facility administrative hierarchy, classifies facilities by ownership, processes selected family planning indicators, and produces a structured Excel dataset for analysis and reporting.

---

##  Overview

The **DHIS2 Data Pipeline** automates the extraction and preparation of facility-level family planning data from the Kenya DHIS2 instance.

The pipeline connects to the DHIS2 Analytics API and processes data for health facilities across the administrative hierarchy.

The resulting dataset combines:

* Facility information
* Facility ownership/grouping
* MFL codes
* Ward
* Sub-county
* County
* Reporting period
* Family planning indicators

The pipeline is designed to make DHIS2 data extraction reproducible and suitable for downstream analysis, reporting, dashboards, and data-quality assessment.

---

## 🔄 Data Pipeline Workflow

```text
                 KHIS / DHIS2
                      │
                      ▼
             DHIS2 Metadata API
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
   Organisation Units        Data Elements
          │
          ▼
   Facility Identification
      (Level 5 Units)
          │
          ▼
   Administrative Hierarchy
          │
          ├── Country
          ├── County
          ├── Sub-county
          ├── Ward
          └── Facility
          │
          ▼
   Facility Ownership Mapping
          │
          ├── Public
          ├── NGO
          ├── Faith Based
          ├── Private
          └── Unclassified
          │
          ▼
      Batch Extraction
       (50 facilities)
          │
          ▼
    DHIS2 Analytics API
          │
          ▼
     Raw Service Data
          │
          ▼
   Indicator Transformation
          │
          ▼
 Aggregation & Restructuring
          │
          ▼
     Final Analytical Dataset
          │
          ▼
        Excel (.xlsx)
```

---

## 🚀 Key Features

* DHIS2 Analytics API integration
* Automated organisation-unit retrieval
* Facility-level data extraction
* Administrative hierarchy mapping
* Facility ownership classification
* Batch processing of facilities
* Extraction across multiple reporting months
* Multiple family planning indicators
* Data aggregation and deduplication
* Wide-format analytical dataset
* Excel output generation
* API error handling
* Empty-response handling
* HTTP status validation
* CSV response parsing
* Configurable batch size
* Configurable reporting period

---

## 🏥 Facility Identification and Hierarchy

The pipeline retrieves DHIS2 organisation units and identifies **Level 5 organisation units as facilities**.

The facility hierarchy is constructed using the parent-child relationships provided by DHIS2.

The resulting hierarchy contains:

| Level      | Field             |
| ---------- | ----------------- |
| Country    | `country_name`    |
| County     | `county_name`     |
| Sub-county | `sub_county_name` |
| Ward       | `ward_name`       |
| Facility   | `facility_name`   |

Each facility is also retained with its DHIS2 organisation-unit identifier:

```text
facility_id
```

The facility code is renamed to:

```text
mfl_code
```

---

## 🏥 Facility Ownership Classification

The pipeline maps DHIS2 organisation-unit groups to facility ownership categories.

The current mapping is:

| DHIS2 Ownership Group | Output Classification |
| --------------------- | --------------------- |
| `AaAF5EmS1fk`         | Public                |
| `g58rumvciv2`         | NGO                   |
| `eT1vvFVhLHc`         | Faith Based           |
| `aRxa6o8GqZN`         | Private               |

Facilities that do not match any of the configured ownership groups receive a missing ownership value (`NA`) and can therefore be treated as **Unclassified** during analysis.

### Ownership field

The resulting dataset contains:

```text
ownership
```

Possible values include:

```text
Public
NGO
Faith Based
Private
NA / Unclassified
```

This allows service-delivery data to be analyzed according to facility ownership.

---

## 💉 Indicators Extracted

The pipeline currently extracts six DHIS2 data-element combinations.

### DMPA-IM

* DMPA-IM New Clients
* DMPA-IM Re-visits

### DMPA-SC

* DMPA-SC New Clients
* DMPA-SC Re-visits

### Hormonal IUD

Two DHIS2 data elements are extracted and combined into the single analytical indicator:

```text
Hormonal_IUD
```

The final indicator set is therefore:

```text
DMPA_IM_New_clients
DMPA_IM_Re_visits
DMPA_SC_New_clients
DMPA_SC_Re_visits
Hormonal_IUD
```

---

## 📅 Reporting Period

The current extraction period is:

```text
January 2025 – August 2026
```

The script uses:

```r
"2025-01-01"
```

as the start date and:

```r
"2026-08-01"
```

as the end date.

The pipeline generates monthly periods between these dates.

---

## 📦 Batch Processing

To reduce the size of individual DHIS2 API requests, facilities are divided into batches.

The current configuration is:

```r
BATCH_SIZE <- 50
```

Therefore, facilities are processed in groups of **50 facilities per API extraction request**.

A two-second pause is also applied between batches:

```r
Sys.sleep(2)
```

This helps reduce continuous request pressure on the DHIS2 server.

---

## 🔐 DHIS2 Connection

The pipeline connects to:

```text
https://hiskenya.dha.go.ke
```

The following DHIS2 API endpoints are used:

### Organisation Units

```text
/api/organisationUnits
```

The pipeline retrieves:

* ID
* Name
* Level
* Code
* Parent
* Organisation-unit groups

### Data Elements

```text
/api/dataElements
```

The pipeline retrieves:

* ID
* Name
* Short name

### Analytics

```text
/api/analytics.csv
```

The Analytics API is used to retrieve the selected indicators for the selected facilities and reporting periods.

---

## 🧹 Data Processing

After extraction, the pipeline performs several transformation steps.

### 1. Period conversion

DHIS2 period values are converted into R monthly date values.

```r
period = ym(period)
```

### 2. Facility metadata join

The extracted service-delivery data is joined with the cleaned facility metadata.

The join uses the DHIS2 organisation-unit ID:

```text
org_unit → facility_id
```

### 3. Indicator identification

DHIS2 data-element identifiers are converted into human-readable indicator names.

### 4. Filtering

Records without a recognized indicator name are removed.

### 5. Aggregation

Records are grouped by:

```text
county_name
sub_county_name
facility_name
org_unit
ownership
period
indicator_name
```

Values are then summed.

This ensures that duplicate records for the same facility, period, ownership, and indicator are consolidated.

### 6. Restructuring

The data is converted from long format into a wide analytical format using `pivot_wider()`.

Each indicator becomes a separate column.

---

## 📋 Final Dataset Structure

The final dataset contains the following main fields:

```text
county_name
sub_county_name
facility_name
org_unit
ownership
period
DMPA_IM_New_clients
DMPA_IM_Re_visits
DMPA_SC_New_clients
DMPA_SC_Re_visits
Hormonal_IUD
```

The dataset therefore provides a facility-level view of family planning service delivery across reporting periods.

---

## 📁 Output

The pipeline currently generates an Excel workbook.

The output filename follows this format:

```text
DHIS2_FP_Injections_YYYY-MM-DD.xlsx
```

For example:

```text
DHIS2_FP_Injections_2026-09-20.xlsx
```

The output location is configured through:

```r
OUTPUT_DIR
```

The current local configuration points to:

```text
C:/Users/Obadia/Desktop/DHIS2
```

The workbook is created using the `openxlsx` package.

---

## 📊 Potential Uses

The resulting dataset can be used for:

* Family planning service-delivery analysis
* Facility-level reporting
* County-level reporting
* Sub-county analysis
* Ownership-group analysis
* DMPA-IM monitoring
* DMPA-SC monitoring
* Hormonal IUD monitoring
* Data-quality assessment
* Dashboard development
* Excel-based reporting
* Power BI data preparation
* Trend analysis across reporting periods

---

## 🧱 Project Structure

```text
dhis2-data-pipeline/
│
├── data_pipeline.R
│   └── Main extraction, transformation and export script
│
├── README.md
│   └── Project documentation
│
└── .gitignore
    └── Files and credentials excluded from Git
```

Generated output files should preferably be stored outside the Git repository or excluded using `.gitignore`.

---

## 📦 Required R Packages

The pipeline uses the following R packages:

```r
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
```

Install them with:

```r
install.packages(c(
  "httr",
  "jsonlite",
  "dplyr",
  "janitor",
  "glue",
  "tidyverse",
  "cli",
  "openxlsx",
  "lubridate",
  "stringr",
  "purrr",
  "readr"
))
```

---

## ▶️ How to Run

### 1. Install R

Install R and, optionally, RStudio.

### 2. Install the required packages

Run:

```r
install.packages(c(
  "httr",
  "jsonlite",
  "dplyr",
  "janitor",
  "glue",
  "tidyverse",
  "cli",
  "openxlsx",
  "lubridate",
  "stringr",
  "purrr",
  "readr"
))
```

### 3. Configure DHIS2 credentials

Credentials should be stored securely as environment variables rather than directly in the script.

For example, create a `.Renviron` file:

```text
DHIS2_USERNAME=your_username
DHIS2_PASSWORD=your_password
DHIS2_BASE_URL=https://hiskenya.dha.go.ke
```

The R script should then retrieve them using:

```r
USERNAME <- Sys.getenv("DHIS2_USERNAME")
PASSWORD <- Sys.getenv("DHIS2_PASSWORD")
BASE_URL <- Sys.getenv("DHIS2_BASE_URL")
```

### 4. Configure the output directory

Modify:

```r
OUTPUT_DIR <- "C:/Users/Obadia/Desktop/DHIS2"
```

if a different output location is required.

### 5. Run the pipeline

From R/RStudio:

```r
source("data_pipeline.R")
```

The pipeline will retrieve the configured DHIS2 data, process the facility metadata and indicators, and save the final Excel dataset.

---

## 🔒 Security

DHIS2 credentials must never be committed to GitHub.

Do not store credentials directly in:

```text
data_pipeline.R
```

Use `.Renviron` or another secure credential-management mechanism.

Add `.Renviron` to `.gitignore`:

```gitignore
.Renviron
```

Also consider excluding generated data files:

```gitignore
*.xlsx
*.csv
output/
```

### Important

The pipeline may process health-service data. Before sharing generated datasets, confirm that the data does not contain information that should not be publicly distributed.

---

## ⚠️ Error Handling

The extraction function checks for several potential API problems.

It handles:

* Request errors
* Non-success HTTP status codes
* Partial HTTP responses (`206`)
* Empty API responses
* CSV parsing failures
* Empty datasets

When a batch cannot be retrieved or parsed, the pipeline generates a warning and continues processing the remaining batches.

---

## ⚙️ Configuration

The following parameters can be changed depending on the extraction requirement.

### DHIS2 Server

```r
BASE_URL
```

### Reporting Period

```r
"2025-01-01"
"2026-08-01"
```

### Indicators

```r
DX <- c(
  ...
)
```

### Batch Size

```r
BATCH_SIZE <- 50
```

### Output Directory

```r
OUTPUT_DIR
```

---

## 🔮 Future Improvements

Potential improvements include:

* Automatic retry with exponential backoff
* Detailed API extraction logs
* Separate raw-data export
* CSV output alongside Excel
* Automated data-quality validation
* Configurable ownership mappings
* Configurable indicator mappings
* Automated scheduling
* Command-line execution
* Docker containerization
* Automated testing
* Pipeline configuration through an external configuration file
* Power BI integration
* Automated reporting

---

## 👤 Author

**Obadia Yano**

**Data Analytics Software Developer**

📧 Email: [Obadiayano45@gmail.com](mailto:Obadiayano45@gmail.com)

📞 Phone: +254 702 268 762

🔗 LinkedIn: https://www.linkedin.com/in/obadia-yano-761025238/

💻 GitHub Portfolio: https://yanoobed.github.io/

---

## 📄 License

This repository currently does not specify an open-source license.

If the code is intended for external reuse or distribution, add an appropriate license to the repository.

---

## 🔗 Repository

**GitHub:**
https://github.com/YanoObed/dhis2-data-pipeline
