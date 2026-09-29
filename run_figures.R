#!/usr/bin/env Rscript

script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    return(sub("^--file=", "", file_arg[[1L]]))
  }
  file.path(getwd(), "run_figures.R")
}

repo_root <- Sys.getenv("REPO_ROOT", unset = "")
if (!nzchar(repo_root)) {
  repo_root <- dirname(normalizePath(script_path(), mustWork = FALSE))
}
repo_root <- normalizePath(repo_root, mustWork = TRUE)
Sys.setenv(REPO_ROOT = repo_root)

run_figure <- function(relative_script, output_subdirectory) {
  run_root <- file.path(repo_root, "outputs", output_subdirectory)
  dir.create(file.path(run_root, "results", "figures"),
             recursive = TRUE, showWarnings = FALSE)
  Sys.setenv(RUN_ROOT = run_root)
  source(file.path(repo_root, relative_script), chdir = FALSE)
}

run_figure(
  file.path("do", "analysis", "multiplier", "Figure1_Multiplier.R"),
  "section3_8_dynamics_eq7"
)
run_figure(
  file.path("do", "analysis", "main", "FigureB4_PriceEffects_ByProduct.R"),
  "section3_7_prices_eq4_eq6"
)

message("Figure generation completed successfully.")
