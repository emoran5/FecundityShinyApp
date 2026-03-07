# CaMP: California Mast Prediction Tool

A Shiny web application that predicts tree seed production (mast) for California Forest Inventory and Analysis (FIA) trees using PRISM climate data and species-specific fecundity models from the MASTIF framework.

---

## What It Does

CaMP forecasts predicted seed production for 11 conifer and oak species across California. Select a year (1990–2025) and one or more species, click **Get Forecasts**, and the app renders an interactive leaflet map where each point is a California FIA tree colored by its predicted seed production value for that year.

**Supported species:**

| Genus | Species |
|-------|---------|
| *Pinus* | *P. ponderosa*, *P. contorta*, *P. jeffreyi*, *P. lambertiana*, *P. monticola* |
| *Quercus* | *Q. kelloggii*, *Q. agrifolia*, *Q. chrysolepis* |
| *Abies* | *A. magnifica*, *A. grandis*, *A. concolor* |

---

## Repository Contents

| File | Description |
|------|-------------|
| `camp_code_02212026_mod.Rmd` | Main Shiny app — knit or run in RStudio |
| `precompute_climate.R` | One-time setup script to extract PRISM climate values (see below) |
| `treeNames.rds` | California FIA tree locations, species, and diameters (~246k trees) |
| `clim_monthly.rds` | Historical climate lookup table (1987–2025, all species) — **~500 MB** |
| `norm_monthly.rds` | 30-year PRISM climate normals lookup table |
| `Pinus_model1_f5_betas.csv` | MASTIF fecundity coefficients for *Pinus* |
| `Quercus_model1_f4_betas.csv` | MASTIF fecundity coefficients for *Quercus* |
| `Abies_model2_f2_betas.csv` | MASTIF fecundity coefficients for *Abies* |

---

## Setup for New Users

### Step 1: Install required R packages

```r
install.packages(c(
  "shiny", "shinyWidgets", "shinycssloaders",
  "leaflet", "dplyr", "readr", "tidyr",
  "terra", "sf", "httr", "showtext",
  "memoise", "cachem", "knitr"
))
```

### Step 2: Obtain the large data files

Because `clim_monthly.rds` (~500 MB) exceeds GitHub's file size limit, it is hosted externally. Download all required `.rds` files and place them in the same folder as `camp_code_02212026_mod.Rmd`:

- `treeNames.rds`
- `clim_monthly.rds`
- `norm_monthly.rds`

> **[Link to data files — add your hosting URL here, e.g., Google Drive, OSF, Zenodo]**

### Step 3: Run the app

Open `camp_code_02212026_mod.Rmd` in RStudio and click **Run Document** (or **Knit**). The app will load the data files on startup (allow 10–20 seconds for `clim_monthly.rds` to load into memory), then the UI will appear.

---

## Do I Need to Run `precompute_climate.R`?

**No — not if you downloaded the precomputed `.rds` files in Step 2.**

`precompute_climate.R` is the one-time script used to generate `clim_monthly.rds` and `norm_monthly.rds` from scratch. It downloads ~936 PRISM raster files (~several GB) from [PRISM Climate Group](https://prism.oregonstate.edu/) and extracts climate values at all FIA tree locations. This process takes several hours and requires a stable internet connection.

You would only need to re-run this script if:
- You want to extend coverage beyond 2025
- The existing `.rds` files are lost or corrupted
- You want to add new species or tree locations

---

## Using the App

1. Use the **year slider** to select a forecast year (1990–2025).
2. Check one or more species in **Select Species for Map**.
3. Click **Get Forecasts**. Status text below the map will update when complete.
4. Click any point on the map for a popup showing species, tree ID, year, and predicted value.
5. Optionally check **Compare All Years** to loop through years using the slider animation.

Forecast time after initial data load is typically under one minute.

---

## Data Sources

- **Climate data:** [PRISM Climate Group](https://prism.oregonstate.edu/), Oregon State University — monthly temperature (tmean) and precipitation (ppt) at 4km resolution
- **Tree locations:** USDA Forest Service [Forest Inventory and Analysis (FIA)](https://www.fia.fs.usda.gov/) — California plot data
- **Fecundity models:** [MASTIF](https://github.com/jimclark-lab/mastif) (Mast Inference and Forecast) — Clark et al., species-specific Bayesian fecundity coefficients

---

## Notes and Limitations

- Predictions use species-specific fecundity equations with climate covariates including temperature and precipitation anomalies, tree diameter, and lagged climate effects (bud initiation and pollination occur in the year prior to seed release for some species).
- The MASTIF beta coefficients were fitted on the original MASTIF climate anomaly scale. Verify with the original model documentation before interpreting absolute predicted values.
- The app currently supports California FIA trees only. Trees outside the PRISM spatial domain will return `NA` and are dropped silently.
