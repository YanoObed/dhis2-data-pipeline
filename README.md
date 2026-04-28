# dhis2-data-pipeline
Automated R pipeline for extracting, cleaning, and transforming DHIS2 data via the analytics API, with batch processing and structured outputs.

# DHIS2 Data Pipeline – KHIS Injectables

## 📊 Overview

This project is an R-based data pipeline that extracts, processes, and exports family planning injectable data from the Kenya Health Information System (DHIS2 / KHIS).

It automates:

* Data extraction via DHIS2 Analytics API
* Transformation and aggregation of indicators
* Facility-level mapping with administrative hierarchy
* Export to Excel and CSV formats



## 🚀 Features

* Batch extraction of facility-level data (optimized for performance)
* Handles API errors and partial responses safely
* Clean and structured output datasets
* Supports multiple indicators (DMPA-IM and DMPA-SC)
* Uses environment variables for secure credential management



## 🧱 Project Structure


├── data_pipeline.R      # Main script
├── README.md           # Project documentation
├── .gitignore          # Ignore sensitive & output files




## 🔐 Environment Setup

This project uses environment variables to keep credentials secure.

### 1. Create a `.Renviron` file

Location:


C:/Users/YourUsername/.Renviron


Add:


DHIS2_USERNAME=your_username
DHIS2_PASSWORD=your_password
DHIS2_BASE_URL=YOURBASE url


Restart R after saving.



## 📦 Required Packages

Install required packages:

r
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




## ▶️ How to Run

1. Open R or RStudio
2. Set working directory to project folder
3. Run:

r
source("data_pipeline.R")


## 📁 Output

The script generates:

* 📄 Excel file (`.xlsx`)
* 📄 CSV file (clean dataset)
* 📄 Raw extracted data

Saved in:


YOUR OUTPUT LOCAL LOCATION



## 📊 Indicators Included

* DMPA-IM New Clients
* DMPA-IM Re-visits
* DMPA-SC New Clients
* DMPA-SC Re-visits



## ⚙️ Configuration

You can modify:

* Date range:

r
"2025-01-01" to "2026-03-01"


* Data elements:

r
DX <- c(...)


* Batch size:

r
BATCH_SIZE <- 50


## ⚠️ Notes

* Ensure DHIS2 credentials are valid
* Large queries are batched to avoid API timeouts
* Do NOT commit `.Renviron` or output data files



## 🛠️ Future Improvements

* Add logging system
* Automate scheduling (cron / task scheduler)
* Add retry logic for failed API calls
* Containerize with Docker



## 👤 Author

Obadia Yano
📧 Email: Obadiayano45@gmail.com
📞 Phone: +254 702 268 762
🔗 LinkedIn: https://www.linkedin.com/in/obadia-yano-761025238/
💻 GitHub Portfolio: https://yanoobed.github.io/

## 📄 License

This project is for internal/public health data use. Add a license if sharing externally.

---
