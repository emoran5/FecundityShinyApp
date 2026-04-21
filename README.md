# CaMP: California Mast Prediction Tool

CaMP is an interactive Shiny application for predicting tree seed production (mast) across California. It uses PRISM climate data extracted at Forest Inventory and Analysis (FIA) tree locations and species-specific fecundity models from the MASTIF framework to produce spatial forecasts of log fecundity for 11 conifer and oak species.

---

## Supported Species

| Genus | Species |
|-------|---------|
| *Pinus* | *P. ponderosa*, *P. jeffreyi*, *P. contorta*, *P. lambertiana*, *P. monticola* |
| *Quercus* | *Q. kelloggii*, *Q. agrifolia*, *Q. chrysolepis* |
| *Abies* | *A. magnifica*, *A. grandis*, *A. concolor* |

---

## Requirements

### R packages
```r
install.packages(c(
  "shiny", "shinyWidgets", "shinycssloaders",
  "leaflet", "plotly",
  "dplyr", "tidyr", "readr",
  "showtext", "httr", "terra", "sf"
))
```

### Data files
The following files must be present in the same folder as `camp_code_04202026.Rmd`:

| File | Description |
|------|-------------|
| `treeNames.rds` | FIA tree locations, species, and diameter data |
| `clim_monthly.rds` | Pre-extracted monthly PRISM climate (1987–2025) at all tree locations |
| `norm_monthly.rds` | Pre-extracted 30-year PRISM climate normals at all tree locations |

> **First-time setup:** If `clim_monthly.rds` or `norm_monthly.rds` do not yet exist, run `precompute_climate.R` once before launching the app. This script downloads and extracts PRISM rasters for all years and species — expect it to take several hours due to download volume. Progress is saved per year so it can be safely interrupted and resumed.

---

## Running the App

Open `camp_code_04202026.Rmd` in RStudio and click **Run Document**, or run:

```r
rmarkdown::run("camp_code_04202026.Rmd")
```

Update the two file paths near the top of the `server` chunk to match your local directory if needed:

```r
CLIM_MONTHLY_PATH <- "~/Desktop/MASTIF cone tool/clim_monthly.rds"
NORM_MONTHLY_PATH <- "~/Desktop/MASTIF cone tool/norm_monthly.rds"
```

---

## Using the Tool

### 1. Select a Year

Use the **Select Year** slider (2005–2026) to choose the forecast year.

- **2005–2025** — historical years with observed PRISM climate data.
- **2026** — no observed data exists yet; the app automatically enters **Custom Scenario** mode and uses 2025 climate as the baseline (see [2026 Scenario](#2026-scenario) below).

The slider can also be animated (▶ button) to step through years sequentially.

### 2. Select Species

Check the species you want to display on the map. Use **Select All Species** or **Uncheck All Species** for convenience. The map updates to show only the selected species when forecasts are run.

### 3. Get Forecasts

Click **Get Forecasts** to compute and display predictions for the selected year and species. A loading spinner appears while the computation runs. The status bar below the map confirms when the run is complete.

---

## Climate Scenario Section

### Use Current Forecast (historical years only)

Displays seed production predictions based on observed PRISM climate for the selected year. The output is log Δ fecundity relative to 30-year climate normals — positive values indicate above-normal predicted seed production, negative values indicate below-normal.

### Use Custom Scenario

Applies user-defined percentage departures to the climate baseline before computing fecundity. Two sliders control the departure:

- **Temperature Departure (%)** — shifts mean temperature by ±50% relative to the baseline.
- **Precipitation Departure (%)** — shifts total precipitation by ±50% relative to the baseline.

The anomaly is computed as:

```
anomaly = observed_climate × (1 + departure%) − 30-yr normal
```

At 0% departure the scenario result is identical to the current forecast, ensuring continuity between modes.

#### Overlay Current Forecast

When this checkbox is enabled in Custom Scenario mode:

- The **main map** shows the scenario forecast.
- A **picture-in-picture inset map** (top-right corner) shows the current (observed) forecast for the same year and species on the same color scale.
- A **scatter plot** appears below the map with one point per tree — current forecast on the x-axis, scenario forecast on the y-axis, colored by species. A dashed 1:1 line indicates no change; points above the line benefit from the scenario conditions and points below are disadvantaged.

**Clicking a point** on the scatter plot highlights the corresponding tree on both maps with a gold ring marker and opens a popup showing the tree ID, species, and both predicted values.

---

## 2026 Scenario

Selecting **2026** activates a special forward-looking mode:

- **Custom Scenario is required** — the "Use Current Forecast" option is automatically disabled because no 2026 observed data exists.
- The **2025 climate** is used as the starting point (the "current forecast baseline").
- The temperature and precipitation sliders define how conditions in 2026 are expected to depart from what was observed in 2025.
- The helper text and inset map label update to reflect that departures are relative to the **2025 forecast**, not 30-year normals.
- When "Overlay current forecast" is checked, the inset map shows the unmodified **2025 forecast** for direct comparison.

This allows users to ask questions like: *"What would mast production look like in 2026 if it is 10% warmer and 20% drier than 2025?"*

---

## Understanding the Map Output

Points on the map represent individual FIA trees, colored on a **red → blue** scale:

| Color | Meaning |
|-------|---------|
| Blue | High predicted log Δ fecundity (above-normal seed production) |
| Red | Low predicted log Δ fecundity (below-normal seed production) |

The legend in the bottom-right of the map shows the value range for the current display. Clicking any tree marker opens a popup with the species, tree ID, year, and predicted value.

---

## Model Background

Fecundity predictions use species-specific regression models from the MASTIF project, which relate diameter and climate anomalies (temperature and precipitation departures from 30-year normals) to log-scale seed production. Climate predictors are grouped into three phenological phases per species:

- **Bud initiation** — typically the prior growing season
- **Pollination** — early spring of the seed year
- **Fertilization** — late spring through summer of the seed year

Each phase uses a different set of months and year lags, drawn from published MASTIF parameter tables. The final output is log Δ fecundity: the log-scale change in predicted seed count attributable to climate conditions for that year.

---

## File Structure

```
MASTIF cone tool/
├── camp_code_04202026.Rmd   # Main Shiny app
├── precompute_climate.R     # One-time data prep script
├── treeNames.rds            # FIA tree data
├── clim_monthly.rds         # Pre-extracted historical climate (generated by precompute_climate.R)
├── norm_monthly.rds         # Pre-extracted climate normals  (generated by precompute_climate.R)
└── README.md                # This file
```

---

## Citation / Acknowledgements

Fecundity model coefficients are derived from the MASTIF (Mast Inference and Forecasting) framework. PRISM climate data are provided by the PRISM Climate Group, Oregon State University (<https://prism.oregonstate.edu>). Tree location data are from the USDA Forest Service Forest Inventory and Analysis program.
