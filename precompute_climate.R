# precompute_climate.R
# ============================================================
# One-time pre-extraction of PRISM climate values at all CA
# FIA tree locations for the 11 supported species.
#
# Outputs (saved to the Desktop folder next to the Rmd):
#   clim_monthly.rds  — historical climate (1987-2025, all months)
#   norm_monthly.rds  — 30-year normals (all months)
#
# After running this script once, the Shiny app can replace
# the slow raster-extract loop with a fast table lookup.
# ============================================================

library(dplyr)
library(terra)
library(sf)
library(httr)

# ---- paths ----------------------------------------------------------------
TREE_RDS   <- "~/Desktop/MASTIF cone tool/treeNames.rds"
OUT_DIR    <- "~/Desktop/MASTIF cone tool"
RMD_PATH   <- "~/Desktop/MASTIF cone tool/camp_code_02212026_mod.Rmd"
RASTER_CACHE <- tools::R_user_dir("fecundity_prism_rasters", which = "cache")
dir.create(RASTER_CACHE, recursive = TRUE, showWarnings = FALSE)

# Source get_prism_data and get_prism_normals_data directly from the Rmd
# so the cache key naming is always identical.
tmp_r <- tempfile(fileext = ".R")
knitr::purl(RMD_PATH, output = tmp_r, quiet = TRUE)
source(tmp_r, local = FALSE)
unlink(tmp_r)

# ---- supported species ---------------------------------------------------
SUPPORTED_SPECIES <- c(
  "Pinus ponderosa", "Pinus contorta",  "Pinus jeffreyi",
  "Pinus lambertiana", "Pinus monticola",
  "Quercus kelloggii", "Quercus agrifolia", "Quercus chrysolepis",
  "Abies magnifica",  "Abies grandis",   "Abies concolor"
)

# ---- load trees ----------------------------------------------------------
message("Loading tree data...")
trees <- readRDS(TREE_RDS) |>
  dplyr::filter(Species %in% SUPPORTED_SPECIES) |>
  dplyr::select(Species, TREE_ID, UTMx, UTMy) |>
  dplyr::distinct()
message(sprintf("  %d trees across %d species", nrow(trees), n_distinct(trees$Species)))

# Build spatial vector once — reused for every extract call
tree_sf  <- sf::st_as_sf(trees, coords = c("UTMx", "UTMy"),
                          crs = "+proj=longlat +datum=WGS84")
tree_vec <- terra::vect(tree_sf)

# get_prism_data and get_prism_normals_data are sourced from the Rmd above.

# ---- helper: extract one raster to a tidy data frame ---------------------
extract_raster <- function(r, tree_vec, trees_df) {
  if (is.null(r)) return(NULL)
  ex <- suppressWarnings(terra::extract(r, tree_vec, bind = FALSE))
  ex <- as.data.frame(ex)
  dplyr::tibble(
    Species = trees_df$Species,
    TREE_ID = trees_df$TREE_ID,
    value   = ex[[2]]
  ) |>
    dplyr::filter(!is.na(value))
}

# ==========================================================================
# 1.  NORMALS  (24 rasters: 12 months × 2 variables, year-independent)
# ==========================================================================
norm_out_path <- file.path(OUT_DIR, "norm_monthly.rds")

if (file.exists(norm_out_path)) {
  message("norm_monthly.rds already exists — skipping normals extraction.")
} else {
  message("\n=== Extracting 30-year normals (24 rasters) ===")
  norm_rows <- list()

  for (var in c("tmean", "ppt")) {
    for (mon in 1:12) {
      msg_tag <- sprintf("  normals %s month %02d", var, mon)
      r <- get_prism_normals_data(mon = mon, variable = var)
      if (is.null(r)) { message(sprintf("%s — skipped", msg_tag)); next }
      message(sprintf("%s — extracting...", msg_tag))

      row_df <- extract_raster(r, tree_vec, trees) |>
        dplyr::mutate(month = mon, variable = var)
      norm_rows[[length(norm_rows) + 1]] <- row_df
      rm(r); gc()
    }
  }

  norm_tidy <- dplyr::bind_rows(norm_rows) |>
    tidyr::pivot_wider(names_from = variable, values_from = value)

  saveRDS(norm_tidy, norm_out_path)
  message(sprintf("Saved norm_monthly.rds (%d rows)", nrow(norm_tidy)))
}

# ==========================================================================
# 2.  HISTORICAL CLIMATE  (years 1987-2025, all months, 2 variables)
#     1987 = 1990 (slider min) - 3 (max lag used by any species)
# ==========================================================================
clim_out_path <- file.path(OUT_DIR, "clim_monthly.rds")

YEARS  <- 1987:2025
MONTHS <- 1:12

if (file.exists(clim_out_path)) {
  message("clim_monthly.rds already exists — skipping historical extraction.")
} else {
  message(sprintf("\n=== Extracting historical climate (%d years × 12 months × 2 variables = %d rasters) ===",
                  length(YEARS), length(YEARS) * 12 * 2))
  message("This will take a while. Progress is saved per-year to allow resuming.")

  clim_parts_dir <- file.path(OUT_DIR, "clim_parts")
  dir.create(clim_parts_dir, showWarnings = FALSE)

  for (yr in YEARS) {
    part_path <- file.path(clim_parts_dir, sprintf("clim_%d.rds", yr))
    if (file.exists(part_path)) {
      message(sprintf("  year %d — already done, skipping.", yr))
      next
    }

    yr_rows <- list()
    for (var in c("tmean", "ppt")) {
      for (mon in MONTHS) {
        r <- tryCatch(
          get_prism_data(month = mon, year = yr, variable = var),
          error = function(e) {
            message(sprintf("  Connection error on %s %d-%02d, retrying in 60s...", var, yr, mon))
            Sys.sleep(60)
            tryCatch(get_prism_data(month = mon, year = yr, variable = var),
                     error = function(e2) { message("  Retry failed, skipping."); NULL })
          }
        )
        if (is.null(r)) next
        row_df <- extract_raster(r, tree_vec, trees) |>
          dplyr::mutate(year = yr, month = mon, variable = var)
        yr_rows[[length(yr_rows) + 1]] <- row_df
        rm(r); gc()
        Sys.sleep(2)  # pause between downloads to avoid PRISM rate limiting
      }
    }

    if (length(yr_rows) > 0) {
      yr_df <- dplyr::bind_rows(yr_rows) |>
        tidyr::pivot_wider(names_from = variable, values_from = value)
      saveRDS(yr_df, part_path)
      message(sprintf("  year %d — saved (%d rows).", yr, nrow(yr_df)))
    }
  }

  # Combine all yearly parts
  message("Combining yearly parts into clim_monthly.rds ...")
  part_files <- list.files(clim_parts_dir, pattern = "clim_\\d{4}\\.rds$",
                           full.names = TRUE)
  clim_all <- lapply(part_files, readRDS) |> dplyr::bind_rows()
  saveRDS(clim_all, clim_out_path)
  message(sprintf("Saved clim_monthly.rds (%d rows).", nrow(clim_all)))
  message("You can delete the clim_parts/ folder now if everything looks good.")
}

message("\nDone. Both lookup tables are ready.")
