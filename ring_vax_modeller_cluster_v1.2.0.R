# ============================================================================
# ERVEBO vs PLACEBO IN BDBV - RING VACCINATION TRIAL SIMULATOR
#
# File: ring_vax_modeller_cluster.R
# Version: 1.2.0
# Authors: Chrissy h. Roberts and Anton Camacho
# License: MIT License
#
# Copyright (c) 2026 Chrissy h. Roberts and Anton Camacho
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED.
# ============================================================================

#
# VERSION HISTORY
# --------------
# 1.1.0 - Documentation release
# 1.2.0 - Deep annotation release
#   - Added plain-English explanations before key model operations.
#   - Clarified the separation between empirical ring generation,
#     randomisation, simulation, and analysis.
#   - Configuration remains concentrated in the user settings section.
#   - Added expanded model documentation and clarified terminology.
#   - Explicitly distinguishes ring generation, randomisation unit, and
#     analysis unit.
#   - Primary analysis population defined as direct/primary contacts.
#   - Contact-of-contact participants retained as operational participants
#     unless explicitly included in sensitivity analyses.
#
# ============================================================================
# ERVEBO vs PLACEBO IN BDBV
# RING-RANDOMISED (CLUSTER-RANDOMISED) TRIAL
#
# SAMPLE-SIZE / PRECISION SIMULATION ACROSS:
#   - placebo direct-contact secondary attack rate (SAR)
#   - true vaccine efficacy (VE)
#
# Adapted from the individually randomised ring_vax_modeller.R model.
# ============================================================================
#
# DESIGN
# ------
# Entire rings are randomised 1:1 to:
#
#       ERVEBO
#          vs
#       PLACEBO / CONTROL
#
# All eligible participants in a ring therefore receive the same assignment.
# The base-case primary VE analysis is restricted to DIRECT CONTACTS.
# Contacts-of-contacts (CoCs) are retained for operational counts and can be
# included in the efficacy analysis by setting PRIMARY_ANALYSIS <- "all".
#
# PRIMARY DESIGN QUESTION
# -----------------------
# Across combinations of placebo direct-contact SAR and true VE, how many
# evaluable rings are required so that at least TARGET_PROBABILITY of simulated
# trials obtain a 95% CI for VE with half-width <= PRECISION_TARGET?
#
# IMPORTANT DIFFERENCE FROM INDIVIDUAL RANDOMISATION
# --------------------------------------------------
# Ring-to-ring heterogeneity now matters directly for precision because a high-
# risk ring contributes to only one treatment arm. RING_RISK_CV is therefore an
# important design assumption and should be explored in sensitivity analyses.
#
# ESTIMAND / ANALYSIS
# -------------------
# VE = 1 - risk ratio.
# Risks are participant-weighted marginal risks within each trial arm.
# Confidence intervals use a ring-cluster robust variance based on ring-level
# residuals, treating rings as the independent units.
#
# SAR INTERPRETATION
# ------------------
# SAR_VALUES should represent the placebo risk of the PRIMARY ENDPOINT during
# the prespecified efficacy window. It should not automatically be interpreted
# as the total cumulative SAR from first exposure if some infections occur
# before randomisation or before vaccine protection could plausibly develop.
# ============================================================================


# ============================================================================
# 0. PACKAGES
# ============================================================================

library(tidyverse)


# ============================================================================
# 1. USER SETTINGS
# ============================================================================

DATA_FILE <- "participants_per_index_R_210621.0311.csv"

OUTPUT_DIR <- "simulation_outputs_ring_randomised"

dir.create(
  OUTPUT_DIR,
  showWarnings = FALSE
)


# ----------------------------------------------------------------------------
# Main SAR x VE grid
# ----------------------------------------------------------------------------

SAR_VALUES <- c(
  0.02,
  0.05,
  0.10,
  0.15,
  0.20,
  0.25,
  0.30,
  0.35,
  0.40
)

TRUE_VES <- c(
  0.10,
  0.20,
  0.30,
  0.40,
  0.50,
  0.60
)


# ----------------------------------------------------------------------------
# Base-case scenario to highlight in output
# ----------------------------------------------------------------------------

PLANNING_SAR <- 0.20
PLANNING_VE  <- 0.20


# ----------------------------------------------------------------------------
# Primary analysis population
# ----------------------------------------------------------------------------
# "direct" = direct contacts only
# "all"    = direct contacts + contacts-of-contacts

PRIMARY_ANALYSIS <- "direct"


# ----------------------------------------------------------------------------
# CoC risk
# ----------------------------------------------------------------------------
# If PRIMARY_ANALYSIS == "all":
#
#   CoC placebo risk = direct-contact ring risk * COC_RISK_MULTIPLIER
#
# This is a sensitivity assumption, not an empirical estimate.

COC_RISK_MULTIPLIER <- 0.05


# ----------------------------------------------------------------------------
# Between-ring heterogeneity in placebo SAR
# ----------------------------------------------------------------------------
# The beta distribution gives each ring its own baseline risk while preserving
# the specified mean SAR.
#
# 0.00 = no between-ring heterogeneity
# 0.25 = modest
# 0.50 = substantial (base case)
# 0.75 = high
# 1.00 = very high
#
# THIS PARAMETER IS MUCH MORE IMPORTANT UNDER RING RANDOMISATION THAN UNDER
# INDIVIDUAL RANDOMISATION.

RING_RISK_CV <- 0.50


# ----------------------------------------------------------------------------
# Precision criterion
# ----------------------------------------------------------------------------

CONFIDENCE_LEVEL <- 0.95

# Current working target: +/- 7.5 percentage points
PRECISION_TARGET <- 0.2

# Require at least 80% probability of achieving the target precision
TARGET_PROBABILITY <- 0.80

# Require most simulated trials to return an estimable VE
MIN_VALID_FRACTION <- 0.95


# ----------------------------------------------------------------------------
# Monte Carlo settings
# ----------------------------------------------------------------------------

# 500 is suitable for an initial coarse run.
# Increase to 2,000-5,000 for more stable protocol-level results.
N_SIM <- 500

# Ring randomisation is balanced 1:1 in pairs, so candidate ring counts must
# be even. A 50-ring coarse step is convenient for the first run.
N_CANDIDATES <- seq(
  from = 50,
  to   = 6000,
  by   = 50
)

SEED <- 20260818
set.seed(SEED)


# ----------------------------------------------------------------------------
# Optional fine search
# ----------------------------------------------------------------------------

RUN_FINE_SEARCH <- FALSE
FINE_STEP <- 10
FINE_WINDOW <- 200
FINE_NSIM <- 3000


# ----------------------------------------------------------------------------
# Optional sensitivity analysis for ring-risk heterogeneity
# ----------------------------------------------------------------------------
# Recommended before finalising the ring-randomised design because cluster
# heterogeneity is a major determinant of the design effect.

RUN_CV_SENSITIVITY <- TRUE

RING_RISK_CV_VALUES <- c(
  0.00,
  0.10,
  0.20,
  0.30,
  0.40,
  0.50,
  0.75,
  1.00
)

CV_SENSITIVITY_NSIM <- 500


# ============================================================================
# 2. READ HISTORICAL DATA
# ============================================================================

df <- read_csv(
  DATA_FILE,
  show_col_types = FALSE
)

cat("\n============================================================\n")
cat("HISTORICAL DATA\n")
cat("============================================================\n")
cat("Rows:", nrow(df), "\n")
cat("Columns:", ncol(df), "\n\n")


# ============================================================================
# 3. CHECK REQUIRED VARIABLES
# ============================================================================

required_variables <- c(
  "eligible_for_vaccine",
  "direct_contact",
  "contact_of_contact"
)

missing_variables <- setdiff(
  required_variables,
  names(df)
)

if (length(missing_variables) > 0) {
  stop(
    paste0(
      "Missing required variables: ",
      paste(missing_variables, collapse = ", ")
    )
  )
}

if (!PRIMARY_ANALYSIS %in% c("direct", "all")) {
  stop("PRIMARY_ANALYSIS must be either 'direct' or 'all'.")
}

if (any(N_CANDIDATES %% 2 != 0)) {
  stop("All N_CANDIDATES must be even for exact 1:1 ring randomisation.")
}


# ============================================================================
# 4. BUILD EMPIRICAL HISTORICAL RING PROFILES
# ============================================================================
# We preserve the empirical joint distribution of:
#   - eligible participants per ring
#   - direct-contact proportion
#
# Each future ring is sampled from one observed historical ring profile.

ring_profiles <- df %>%
  transmute(
    eligible_total = round(eligible_for_vaccine),
    direct_contact = pmax(round(direct_contact), 0),
    contact_of_contact = pmax(round(contact_of_contact), 0),
    listed_contact_total = direct_contact + contact_of_contact
  ) %>%
  filter(
    !is.na(eligible_total),
    eligible_total >= 2,
    !is.na(listed_contact_total),
    listed_contact_total > 0
  ) %>%
  mutate(
    prop_direct = direct_contact / listed_contact_total,
    prop_direct = pmin(pmax(prop_direct, 0), 1)
  ) %>%
  select(
    eligible_total,
    prop_direct
  )

if (nrow(ring_profiles) < 10) {
  stop("Too few usable historical ring profiles after cleaning.")
}

cat("Usable historical ring profiles:", nrow(ring_profiles), "\n")

cat(
  "Mean eligible participants/ring:",
  round(mean(ring_profiles$eligible_total), 1),
  "\n"
)

cat(
  "Median eligible participants/ring:",
  round(median(ring_profiles$eligible_total), 1),
  "\n"
)

cat(
  "Mean direct-contact proportion:",
  round(mean(ring_profiles$prop_direct), 3),
  "\n"
)

cat(
  "Median direct-contact proportion:",
  round(median(ring_profiles$prop_direct), 3),
  "\n\n"
)


# ============================================================================
# 5. HISTORICAL RING PLOTS
# ============================================================================

p_ring_size <- ring_profiles %>%
  ggplot(aes(x = eligible_total)) +
  geom_histogram(bins = 50) +
  geom_vline(
    xintercept = median(ring_profiles$eligible_total),
    linetype = "dashed"
  ) +
  labs(
    title = "Historical Distribution of Eligible Participants per Ring",
    subtitle = paste0(
      "Median = ",
      round(median(ring_profiles$eligible_total), 0),
      "; mean = ",
      round(mean(ring_profiles$eligible_total), 0)
    ),
    x = "Eligible participants per ring",
    y = "Number of rings"
  ) +
  theme_minimal() +
  theme(
    plot.title.position = "plot"
  )

print(p_ring_size)

ggsave(
  file.path(
    OUTPUT_DIR,
    "historical_eligible_ring_size.png"
  ),
  p_ring_size,
  width = 8,
  height = 5,
  dpi = 300
)


p_direct_prop <- ring_profiles %>%
  ggplot(
    aes(x = prop_direct)
  ) +
  geom_histogram(
    bins = 40
  ) +
  geom_vline(
    xintercept = median(ring_profiles$prop_direct),
    linetype = "dashed"
  ) +
  scale_x_continuous(
    labels = scales::percent
  ) +
  labs(
    title = "Historical Direct-Contact Proportion Within Rings",
    x = "Direct contacts / (direct contacts + contacts-of-contacts)",
    y = "Number of rings"
  ) +
  theme_minimal() +
  theme(
    plot.title.position = "plot"
  )

print(p_direct_prop)

ggsave(
  file.path(
    OUTPUT_DIR,
    "historical_direct_contact_proportion.png"
  ),
  p_direct_prop,
  width = 8,
  height = 5,
  dpi = 300
)


# ============================================================================
# 6. HELPER:
#    BETA-DISTRIBUTED RING RISK WITH SPECIFIED MEAN AND CV
# ============================================================================

rbeta_mean_cv <- function(
    n,
    mean_risk,
    cv
) {

  if (mean_risk <= 0 || mean_risk >= 1) {
    stop(
      "mean_risk must lie between 0 and 1."
    )
  }

  if (cv < 0) {
    stop(
      "cv must be >= 0."
    )
  }

  if (cv == 0) {
    return(
      rep(
        mean_risk,
        n
      )
    )
  }


  # For Beta(alpha, beta):
  #
  # mean = mu
  #
  # var = mu(1-mu)/(phi+1)
  #
  # CV^2 = var / mu^2
  #
  # Therefore:
  #
  # phi = (1-mu)/(mu*CV^2) - 1


  phi <-
    (1 - mean_risk) /
    (
      mean_risk *
        cv^2
    ) -
    1


  if (phi <= 0) {

    stop(
      paste0(
        "Requested SAR/CV combination is incompatible ",
        "with a beta distribution. ",
        "Reduce RING_RISK_CV. SAR=",
        mean_risk,
        ", CV=",
        cv
      )
    )

  }


  alpha <-
    mean_risk *
    phi


  beta <-
    (1 - mean_risk) *
    phi


  rbeta(
    n = n,
    shape1 = alpha,
    shape2 = beta
  )
}


# ============================================================================
# 7. HELPER:
#    EXACT 1:1 RING RANDOMISATION IN PAIRS
# ============================================================================
#
# Each consecutive pair contains exactly one Ervebo ring and one placebo ring,
# with the order randomly chosen.
#
# Therefore every even cumulative ring count has exact 1:1 allocation.

# ------------------------------------------------------------------------------
# FUNCTION: randomise_rings_1to1
#
# PURPOSE:
# Randomises complete rings equally between vaccine and control arms.
# The entire ring receives the same allocation because this is a
# cluster (ring)-randomised design.
# ------------------------------------------------------------------------------

randomise_rings_1to1 <- function(
    n_rings
) {

  if (
    n_rings %% 2 != 0
  ) {

    stop(
      "n_rings must be even for exact 1:1 pair randomisation."
    )

  }


  first_in_pair <- rbinom(
    n = n_rings / 2,
    size = 1,
    prob = 0.5
  )


  # 1 = Ervebo
  # 0 = placebo

  as.vector(
    rbind(
      first_in_pair,
      1L - first_in_pair
    )
  )
}


# ============================================================================
# 8. HELPER:
#    RING-CLUSTER ROBUST ARM STATISTICS
# ============================================================================
#
# For each arm:
#
#     risk = total cases / total participants
#
# Treat rings as independent clusters.
#
# The variance of the pooled risk is estimated from ring-level residuals:
#
#     residual_i = cases_i - risk * N_i
#
# This accommodates unequal ring sizes and extra variation between rings.

cluster_arm_stats <- function(
    n_clusters,
    sum_cases,
    sum_people,
    sum_cases2,
    sum_case_people,
    sum_people2
) {

  risk <- ifelse(
    sum_people > 0,
    sum_cases / sum_people,
    NA_real_
  )


  residual_ss <-
    sum_cases2 -
    2 *
    risk *
    sum_case_people +
    risk^2 *
    sum_people2


  residual_ss <-
    pmax(
      residual_ss,
      0
    )


  var_risk <- ifelse(

    n_clusters > 1 &
      sum_cases > 0 &
      sum_people > 0 &
      risk > 0,

    (
      n_clusters /
        (n_clusters - 1)
    ) *
      residual_ss /
      sum_people^2,

    NA_real_

  )


  var_log_risk <- ifelse(

    is.finite(var_risk) &
      risk > 0,

    var_risk /
      risk^2,

    NA_real_

  )


  list(

    risk =
      risk,

    var_log_risk =
      var_log_risk

  )
}


# ============================================================================
# 9. MAIN SIMULATION:
#    ONE SAR x VE PRECISION CURVE
# ============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: simulate_precision_curve_ring_randomised
#
# PURPOSE:
# Simulates complete ring-randomised trials across SAR and vaccine efficacy
# assumptions, then estimates the number of rings needed to achieve the
# prespecified precision target.
# ------------------------------------------------------------------------------

simulate_precision_curve_ring_randomised <- function(

  n_candidates,

  true_ve,

  sar,

  ring_profiles,

  ring_risk_cv = 0.50,

  primary_analysis = "direct",

  coc_risk_multiplier = 0.05,

  nsim = 500,

  precision_target = 0.075,

  confidence = 0.95

) {


  # --------------------------------------------------------------------------
  # Input checks
  # --------------------------------------------------------------------------

  stopifnot(

    true_ve >= 0,

    true_ve < 1,

    sar > 0,

    sar < 1,

    ring_risk_cv >= 0,

    coc_risk_multiplier >= 0,

    nsim > 0

  )


  if (
    !primary_analysis %in%
    c(
      "direct",
      "all"
    )
  ) {

    stop(
      "primary_analysis must be 'direct' or 'all'."
    )

  }


  n_candidates <-

    sort(
      unique(
        as.integer(
          n_candidates
        )
      )
    )


  if (
    any(
      n_candidates %% 2 != 0
    )
  ) {

    stop(
      "All candidate ring counts must be even."
    )

  }


  max_n <-
    max(
      n_candidates
    )


  k <-
    length(
      n_candidates
    )


  alpha <-
    1 -
    confidence



  # --------------------------------------------------------------------------
  # Storage matrices
  # --------------------------------------------------------------------------

  ve_hat_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  lower_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  upper_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  half_width_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  valid_mat <-

    matrix(
      FALSE,
      nrow = nsim,
      ncol = k
    )


  placebo_cases_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  vaccine_cases_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  analysis_n_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  all_enrolled_n_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  direct_n_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  coc_n_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )



  # ==========================================================================
  # MONTE CARLO LOOP
  # ==========================================================================

  for (
    s in seq_len(nsim)
  ) {


    # ------------------------------------------------------------------------
    # A. Sample empirical historical ring profiles
    # ------------------------------------------------------------------------

    sampled_idx <-

      sample.int(

        n =
          nrow(
            ring_profiles
          ),

        size =
          max_n,

        replace =
          TRUE

      )


    prof <-

      ring_profiles[
        sampled_idx,
      ]


    eligible_total <-

      as.integer(
        prof$eligible_total
      )


    prop_direct <-

      prof$prop_direct



    # ------------------------------------------------------------------------
    # B. Simulate direct contacts and CoCs within each ring
    # ------------------------------------------------------------------------

    n_direct <-

      rbinom(

        n =
          max_n,

        size =
          eligible_total,

        prob =
          prop_direct

      )


    n_coc <-

      eligible_total -
      n_direct



    # ------------------------------------------------------------------------
    # C. RANDOMISE ENTIRE RINGS 1:1
    # ------------------------------------------------------------------------

    arm <-

      randomise_rings_1to1(
        max_n
      )


    is_vaccine <-

      arm ==
      1


    is_placebo <-

      arm ==
      0



    # ------------------------------------------------------------------------
    # D. Ring-specific placebo direct-contact SAR
    # ------------------------------------------------------------------------

    p_direct_placebo <-

      rbeta_mean_cv(

        n =
          max_n,

        mean_risk =
          sar,

        cv =
          ring_risk_cv

      )


    p_direct_vaccine <-

      p_direct_placebo *
      (
        1 -
          true_ve
      )



    # ------------------------------------------------------------------------
    # CoC risk, if needed
    # ------------------------------------------------------------------------

    p_coc_placebo <-

      pmin(

        p_direct_placebo *
          coc_risk_multiplier,

        0.999999

      )


    p_coc_vaccine <-

      p_coc_placebo *
      (
        1 -
          true_ve
      )



    # ------------------------------------------------------------------------
    # E. Generate ring-level outcomes
    # ------------------------------------------------------------------------

    cases_direct <-

      ifelse(

        is_vaccine,

        rbinom(
          max_n,
          size = n_direct,
          prob = p_direct_vaccine
        ),

        rbinom(
          max_n,
          size = n_direct,
          prob = p_direct_placebo
        )

      )


    cases_coc <-

      ifelse(

        is_vaccine,

        rbinom(
          max_n,
          size = n_coc,
          prob = p_coc_vaccine
        ),

        rbinom(
          max_n,
          size = n_coc,
          prob = p_coc_placebo
        )

      )



    # ------------------------------------------------------------------------
    # F. Primary analysis population
    # ------------------------------------------------------------------------

    if (
      primary_analysis ==
      "direct"
    ) {


      cases <-
        cases_direct


      people <-
        n_direct


    } else {


      cases <-

        cases_direct +
        cases_coc


      people <-

        n_direct +
        n_coc

    }



    # ------------------------------------------------------------------------
    # G. Cumulative sufficient statistics by trial arm
    # ------------------------------------------------------------------------

    placebo_n_clusters <-

      cumsum(
        as.numeric(
          is_placebo &
            people > 0
        )
      )


    placebo_cases <-

      cumsum(
        cases *
          is_placebo
      )


    placebo_people <-

      cumsum(
        people *
          is_placebo
      )


    placebo_cases2 <-

      cumsum(
        cases^2 *
          is_placebo
      )


    placebo_case_people <-

      cumsum(
        cases *
          people *
          is_placebo
      )


    placebo_people2 <-

      cumsum(
        people^2 *
          is_placebo
      )



    vaccine_n_clusters <-

      cumsum(
        as.numeric(
          is_vaccine &
            people > 0
        )
      )


    vaccine_cases <-

      cumsum(
        cases *
          is_vaccine
      )


    vaccine_people <-

      cumsum(
        people *
          is_vaccine
      )


    vaccine_cases2 <-

      cumsum(
        cases^2 *
          is_vaccine
      )


    vaccine_case_people <-

      cumsum(
        cases *
          people *
          is_vaccine
      )


    vaccine_people2 <-

      cumsum(
        people^2 *
          is_vaccine
      )


    cum_all_enrolled <-

      cumsum(
        eligible_total
      )


    cum_direct <-

      cumsum(
        n_direct
      )


    cum_coc <-

      cumsum(
        n_coc
      )


    idx <-

      n_candidates



    # ------------------------------------------------------------------------
    # H. Ring-cluster robust arm estimates
    # ------------------------------------------------------------------------

    p_stats <-

      cluster_arm_stats(

        n_clusters =
          placebo_n_clusters[
            idx
          ],

        sum_cases =
          placebo_cases[
            idx
          ],

        sum_people =
          placebo_people[
            idx
          ],

        sum_cases2 =
          placebo_cases2[
            idx
          ],

        sum_case_people =
          placebo_case_people[
            idx
          ],

        sum_people2 =
          placebo_people2[
            idx
          ]

      )


    v_stats <-

      cluster_arm_stats(

        n_clusters =
          vaccine_n_clusters[
            idx
          ],

        sum_cases =
          vaccine_cases[
            idx
          ],

        sum_people =
          vaccine_people[
            idx
          ],

        sum_cases2 =
          vaccine_cases2[
            idx
          ],

        sum_case_people =
          vaccine_case_people[
            idx
          ],

        sum_people2 =
          vaccine_people2[
            idx
          ]

      )



    # ------------------------------------------------------------------------
    # I. Risk ratio, VE and CI
    # ------------------------------------------------------------------------

    log_rr <-

      log(
        v_stats$risk /
          p_stats$risk
      )


    se_log_rr <-

      sqrt(
        v_stats$var_log_risk +
          p_stats$var_log_risk
      )


    valid <-

      is.finite(
        log_rr
      ) &

      is.finite(
        se_log_rr
      ) &

      se_log_rr >
      0


    ve_hat <-

      1 -
      exp(
        log_rr
      )



    # Use a cluster-based t critical value rather than 1.96.
    #
    # This is more conservative when the number of rings is modest and
    # approaches the usual normal critical value as ring numbers increase.

    cluster_df <-

      placebo_n_clusters[
        idx
      ] +

      vaccine_n_clusters[
        idx
      ] -

      2


    critical_value <-

      qt(

        1 -
          alpha /
          2,

        df =
          pmax(
            cluster_df,
            1
          )

      )


    valid <-

      valid &

      cluster_df >
      0 &

      is.finite(
        critical_value
      )


    ci_lower <-

      1 -
      exp(
        log_rr +
          critical_value *
          se_log_rr
      )


    ci_upper <-

      1 -
      exp(
        log_rr -
          critical_value *
          se_log_rr
      )


    half_width <-

      (
        ci_upper -
          ci_lower
      ) /
      2


    ve_hat[
      !valid
    ] <-

      NA_real_


    ci_lower[
      !valid
    ] <-

      NA_real_


    ci_upper[
      !valid
    ] <-

      NA_real_


    half_width[
      !valid
    ] <-

      NA_real_



    # ------------------------------------------------------------------------
    # J. Store
    # ------------------------------------------------------------------------

    ve_hat_mat[
      s,
    ] <-

      ve_hat


    lower_mat[
      s,
    ] <-

      ci_lower


    upper_mat[
      s,
    ] <-

      ci_upper


    half_width_mat[
      s,
    ] <-

      half_width


    valid_mat[
      s,
    ] <-

      valid


    placebo_cases_mat[
      s,
    ] <-

      placebo_cases[
        idx
      ]


    vaccine_cases_mat[
      s,
    ] <-

      vaccine_cases[
        idx
      ]


    analysis_n_mat[
      s,
    ] <-

      placebo_people[
        idx
      ] +

      vaccine_people[
        idx
      ]


    all_enrolled_n_mat[
      s,
    ] <-

      cum_all_enrolled[
        idx
      ]


    direct_n_mat[
      s,
    ] <-

      cum_direct[
        idx
      ]


    coc_n_mat[
      s,
    ] <-

      cum_coc[
        idx
      ]

  }



  # --------------------------------------------------------------------------
  # Summarise Monte Carlo results at each candidate ring count
  # --------------------------------------------------------------------------

  map_dfr(

    seq_len(k),

    function(j) {


      ok <-

        valid_mat[
          ,
          j
        ]


      n_valid <-

        sum(
          ok
        )


      # Invalid simulations count as failures to achieve precision

      precision_success <-

        ok &

        half_width_mat[
          ,
          j
        ] <=
        precision_target



      if (
        n_valid ==
        0
      ) {


        return(

          tibble(

            sar =
              sar,

            true_ve =
              true_ve,

            n_rings =
              n_candidates[j],

            vaccine_rings =
              n_candidates[j] /
              2,

            placebo_rings =
              n_candidates[j] /
              2,

            valid_fraction =
              0,

            mean_ve =
              NA_real_,

            median_ve =
              NA_real_,

            bias =
              NA_real_,

            median_ci_half_width =
              NA_real_,

            probability_precision =
              0,

            coverage =
              NA_real_,

            mean_analysis_participants =
              mean(
                analysis_n_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_all_enrolled_participants =
              mean(
                all_enrolled_n_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_direct_contacts =
              mean(
                direct_n_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_coc =
              mean(
                coc_n_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_placebo_cases =
              mean(
                placebo_cases_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_vaccine_cases =
              mean(
                vaccine_cases_mat[
                  ,
                  j
                ],
                na.rm = TRUE
              ),

            mean_total_cases =
              mean(

                placebo_cases_mat[
                  ,
                  j
                ] +

                  vaccine_cases_mat[
                    ,
                    j
                  ],

                na.rm =
                  TRUE

              )

          )

        )

      }



      tibble(

        sar =
          sar,

        true_ve =
          true_ve,

        n_rings =
          n_candidates[j],

        vaccine_rings =
          n_candidates[j] /
          2,

        placebo_rings =
          n_candidates[j] /
          2,

        valid_fraction =
          mean(
            ok
          ),

        mean_ve =
          mean(
            ve_hat_mat[
              ok,
              j
            ],
            na.rm = TRUE
          ),

        median_ve =
          median(
            ve_hat_mat[
              ok,
              j
            ],
            na.rm = TRUE
          ),

        bias =
          mean(
            ve_hat_mat[
              ok,
              j
            ],
            na.rm = TRUE
          ) -
          true_ve,

        median_ci_half_width =
          median(
            half_width_mat[
              ok,
              j
            ],
            na.rm = TRUE
          ),

        probability_precision =
          mean(
            precision_success
          ),

        coverage =
          mean(

            lower_mat[
              ok,
              j
            ] <=
              true_ve &

              upper_mat[
                ok,
                j
              ] >=
              true_ve,

            na.rm =
              TRUE

          ),

        mean_analysis_participants =
          mean(
            analysis_n_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_all_enrolled_participants =
          mean(
            all_enrolled_n_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_direct_contacts =
          mean(
            direct_n_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_coc =
          mean(
            coc_n_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_placebo_cases =
          mean(
            placebo_cases_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_vaccine_cases =
          mean(
            vaccine_cases_mat[
              ,
              j
            ],
            na.rm = TRUE
          ),

        mean_total_cases =
          mean(

            placebo_cases_mat[
              ,
              j
            ] +

              vaccine_cases_mat[
                ,
                j
              ],

            na.rm =
              TRUE

          )

      )

    }

  )

}


# ============================================================================
# 10. RUN PRIMARY SAR x VE GRID
# ============================================================================

cat("============================================================\n")
cat("STARTING RING-RANDOMISED SAR x VE SIMULATION\n")
cat("============================================================\n")

cat(
  "Primary analysis:",
  PRIMARY_ANALYSIS,
  "\n"
)

cat(
  "Ring-risk CV:",
  RING_RISK_CV,
  "\n"
)

cat(
  "Precision target: +/-",
  PRECISION_TARGET * 100,
  "percentage points\n"
)

cat(
  "Target probability:",
  TARGET_PROBABILITY * 100,
  "%\n"
)

cat(
  "Simulations per SAR x VE scenario:",
  N_SIM,
  "\n\n"
)


scenario_grid <-

  crossing(

    sar =
      SAR_VALUES,

    true_ve =
      TRUE_VES

  )


results_primary <-

  pmap_dfr(

    scenario_grid,

    function(
    sar,
    true_ve
    ) {


      cat(

        "SAR =",
        scales::percent(
          sar,
          accuracy = 1
        ),

        "| VE =",
        scales::percent(
          true_ve,
          accuracy = 1
        ),

        "\n"

      )


      simulate_precision_curve_ring_randomised(

        n_candidates =
          N_CANDIDATES,

        true_ve =
          true_ve,

        sar =
          sar,

        ring_profiles =
          ring_profiles,

        ring_risk_cv =
          RING_RISK_CV,

        primary_analysis =
          PRIMARY_ANALYSIS,

        coc_risk_multiplier =
          COC_RISK_MULTIPLIER,

        nsim =
          N_SIM,

        precision_target =
          PRECISION_TARGET,

        confidence =
          CONFIDENCE_LEVEL

      )

    }

  )


results_primary <-

  results_primary %>%

  mutate(

    sar_percent =
      sar * 100,

    true_ve_percent =
      true_ve * 100,

    median_margin_error_percent =
      median_ci_half_width * 100,

    probability_precision_percent =
      probability_precision * 100,

    coverage_percent =
      coverage * 100

  )


write_csv(

  results_primary,

  file.path(
    OUTPUT_DIR,
    "primary_sar_ve_simulation_results.csv"
  )

)


# ============================================================================
# 11. MINIMUM RINGS FOR EACH SAR x VE SCENARIO
# ============================================================================

threshold_results <-

  results_primary %>%

  filter(

    valid_fraction >=
      MIN_VALID_FRACTION,

    probability_precision >=
      TARGET_PROBABILITY

  ) %>%

  group_by(
    sar,
    true_ve
  ) %>%

  slice_min(

    order_by =
      n_rings,

    n =
      1,

    with_ties =
      FALSE

  ) %>%

  ungroup()


minimum_grid <-

  crossing(

    sar =
      SAR_VALUES,

    true_ve =
      TRUE_VES

  ) %>%

  left_join(

    threshold_results,

    by =
      c(
        "sar",
        "true_ve"
      )

  ) %>%

  mutate(

    sar_percent =
      sar * 100,

    true_ve_percent =
      true_ve * 100,

    threshold_reached =
      !is.na(
        n_rings
      )

  )


write_csv(

  minimum_grid,

  file.path(
    OUTPUT_DIR,
    "minimum_rings_by_sar_and_ve.csv"
  )

)


cat("\n")
cat("============================================================\n")
cat("MINIMUM RINGS BY SAR AND VE\n")
cat("============================================================\n\n")


print(

  minimum_grid %>%

    select(

      sar_percent,

      true_ve_percent,

      n_rings,

      vaccine_rings,

      placebo_rings,

      mean_all_enrolled_participants,

      mean_analysis_participants,

      mean_total_cases,

      probability_precision,

      median_ci_half_width,

      coverage,

      threshold_reached

    ),

  n =
    Inf

)


if (
  any(
    !minimum_grid$threshold_reached
  )
) {

  cat("\nWARNING:\n")

  cat(
    "At least one SAR x VE scenario did not reach the target within the ",
    "current N_CANDIDATES range. Increase max(N_CANDIDATES) and rerun.\n"
  )

}


# ============================================================================
# 12. HIGHLIGHT THE CURRENT PLANNING SCENARIO
# ============================================================================

planning_scenario <-

  minimum_grid %>%

  filter(

    abs(
      sar -
        PLANNING_SAR
    ) <
      1e-12,

    abs(
      true_ve -
        PLANNING_VE
    ) <
      1e-12

  )


cat("\n")
cat("============================================================\n")
cat("CURRENT PLANNING SCENARIO\n")
cat("============================================================\n")

cat(
  "SAR:",
  PLANNING_SAR * 100,
  "%\n"
)

cat(
  "True VE:",
  PLANNING_VE * 100,
  "%\n"
)

cat(
  "Precision: +/-",
  PRECISION_TARGET * 100,
  "percentage points\n"
)

cat(
  "Target probability:",
  TARGET_PROBABILITY * 100,
  "%\n\n"
)


print(
  planning_scenario
)


write_csv(

  planning_scenario,

  file.path(
    OUTPUT_DIR,
    "planning_scenario_SAR20_VE20.csv"
  )

)


# ============================================================================
# 13. CLEAN REPORTING TABLE
# ============================================================================

summary_table <-

  minimum_grid %>%

  transmute(

    `Placebo direct-contact SAR (%)` =
      sar_percent,

    `True VE (%)` =
      true_ve_percent,

    `Minimum total rings` =
      n_rings,

    `Ervebo rings` =
      vaccine_rings,

    `Placebo rings` =
      placebo_rings,

    `Total enrolled participants` =
      round(
        mean_all_enrolled_participants,
        0
      ),

    `Primary-analysis participants` =
      round(
        mean_analysis_participants,
        0
      ),

    `Direct contacts` =
      round(
        mean_direct_contacts,
        0
      ),

    `Contacts-of-contacts` =
      round(
        mean_coc,
        0
      ),

    `Expected placebo endpoint cases` =
      round(
        mean_placebo_cases,
        1
      ),

    `Expected Ervebo endpoint cases` =
      round(
        mean_vaccine_cases,
        1
      ),

    `Expected total endpoint cases` =
      round(
        mean_total_cases,
        1
      ),

    `Probability target precision (%)` =
      round(
        probability_precision * 100,
        1
      ),

    `Median 95% CI half-width (pp)` =
      round(
        median_ci_half_width * 100,
        2
      ),

    `Coverage (%)` =
      round(
        coverage * 100,
        1
      ),

    `Threshold reached` =
      threshold_reached

  )


print(
  summary_table,
  n = Inf
)


write_csv(

  summary_table,

  file.path(
    OUTPUT_DIR,
    "sample_size_summary_sar_ve.csv"
  )

)


# ============================================================================
# 14. HEATMAP:
#     REQUIRED NUMBER OF RINGS
# ============================================================================

p_rings_heatmap <-

  minimum_grid %>%

  mutate(

    sar_label =
      paste0(
        sar_percent,
        "%"
      ),

    ve_label =
      paste0(
        true_ve_percent,
        "%"
      ),

    n_label =
      ifelse(
        is.na(
          n_rings
        ),
        "> max",
        as.character(
          n_rings
        )
      ),

    text_colour =
      ifelse(

        is.na(
          n_rings
        ),

        "black",

        ifelse(

          n_rings >
            median(
              n_rings,
              na.rm = TRUE
            ),

          "white",

          "black"

        )

      )

  ) %>%

  ggplot(

    aes(

      x =
        factor(

          sar_label,

          levels =
            paste0(
              SAR_VALUES * 100,
              "%"
            )

        ),

      y =
        factor(

          ve_label,

          levels =
            rev(
              paste0(
                TRUE_VES * 100,
                "%"
              )
            )

        ),

      fill =
        n_rings

    )

  ) +

  geom_tile(

    colour =
      "white",

    linewidth =
      0.8

  ) +

  geom_text(

    aes(

      label =
        n_label,

      colour =
        text_colour

    ),

    size =
      4.2,

    fontface =
      "bold"

  ) +

  scale_fill_gradient(

    low =
      "#F7FBFF",

    high =
      "#08306B",

    na.value =
      "grey85",

    labels =
      scales::comma

  ) +

  scale_colour_identity() +

  labs(

    title =
      "Rings Required for Target VE Precision",

    subtitle =
      paste0(

        "1:1 randomisation of entire rings; ",

        TARGET_PROBABILITY * 100,

        "% probability of 95% CI margin ≤ ±",

        PRECISION_TARGET * 100,

        " percentage points; ring-risk CV = ",

        RING_RISK_CV

      ),

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "True vaccine efficacy",

    fill =
      "Rings required"

  ) +

  theme_minimal(
    base_size = 13
  ) +

  theme(

    plot.title.position =
      "plot",

    plot.title =
      element_text(
        face = "bold",
        size = 18
      ),

    plot.subtitle =
      element_text(
        size = 12,
        colour = "grey30"
      ),

    axis.title =
      element_text(
        face = "bold"
      ),

    axis.text =
      element_text(
        colour = "grey20"
      ),

    panel.grid =
      element_blank(),

    legend.position =
      "right"

  )


print(
  p_rings_heatmap
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "required_rings_heatmap.png"
  ),

  p_rings_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)


# ============================================================================
# 15. HEATMAP:
#     TOTAL ENROLLED PARTICIPANTS
# ============================================================================

p_participants_heatmap <-

  minimum_grid %>%

  mutate(

    sar_label =
      paste0(
        sar_percent,
        "%"
      ),

    ve_label =
      paste0(
        true_ve_percent,
        "%"
      ),

    n_label =
      ifelse(

        is.na(
          mean_all_enrolled_participants
        ),

        "> max",

        scales::comma(
          round(
            mean_all_enrolled_participants,
            0
          )
        )

      ),

    text_colour =
      ifelse(

        is.na(
          mean_all_enrolled_participants
        ),

        "black",

        ifelse(

          mean_all_enrolled_participants >
            median(
              mean_all_enrolled_participants,
              na.rm = TRUE
            ),

          "white",

          "black"

        )

      )

  ) %>%

  ggplot(

    aes(

      x =
        factor(
          sar_label,
          levels =
            paste0(
              SAR_VALUES * 100,
              "%"
            )
        ),

      y =
        factor(
          ve_label,
          levels =
            rev(
              paste0(
                TRUE_VES * 100,
                "%"
              )
            )
        ),

      fill =
        mean_all_enrolled_participants

    )

  ) +

  geom_tile(
    colour = "white",
    linewidth = 0.8
  ) +

  geom_text(

    aes(
      label = n_label,
      colour = text_colour
    ),

    size = 3.4,

    fontface = "bold"

  ) +

  scale_fill_gradient(

    low = "#F7FBFF",

    high = "#08306B",

    na.value = "grey85",

    labels = scales::comma

  ) +

  scale_colour_identity() +

  labs(

    title =
      "Total Participants Enrolled in Ring-Randomised Trial",

    subtitle =
      "Includes direct contacts and contacts-of-contacts in enrolled rings",

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "True vaccine efficacy",

    fill =
      "Participants"

  ) +

  theme_minimal(
    base_size = 13
  ) +

  theme(

    plot.title.position =
      "plot",

    plot.title =
      element_text(
        face = "bold",
        size = 18
      ),

    axis.title =
      element_text(
        face = "bold"
      ),

    panel.grid =
      element_blank()

  )


print(
  p_participants_heatmap
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "required_participants_heatmap.png"
  ),

  p_participants_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)


# ============================================================================
# 16. HEATMAP:
#     EXPECTED PRIMARY ENDPOINT CASES
# ============================================================================

p_cases_heatmap <-

  minimum_grid %>%

  mutate(

    sar_label =
      paste0(
        sar_percent,
        "%"
      ),

    ve_label =
      paste0(
        true_ve_percent,
        "%"
      ),

    cases_label =
      ifelse(

        is.na(
          mean_total_cases
        ),

        "> max",

        round(
          mean_total_cases,
          0
        )

      ),

    text_colour =
      ifelse(

        is.na(
          mean_total_cases
        ),

        "black",

        ifelse(

          mean_total_cases >
            median(
              mean_total_cases,
              na.rm = TRUE
            ),

          "white",

          "black"

        )

      )

  ) %>%

  ggplot(

    aes(

      x =
        factor(
          sar_label,
          levels =
            paste0(
              SAR_VALUES * 100,
              "%"
            )
        ),

      y =
        factor(
          ve_label,
          levels =
            rev(
              paste0(
                TRUE_VES * 100,
                "%"
              )
            )
        ),

      fill =
        mean_total_cases

    )

  ) +

  geom_tile(
    colour = "white",
    linewidth = 0.8
  ) +

  geom_text(

    aes(
      label = cases_label,
      colour = text_colour
    ),

    size = 4,

    fontface = "bold"

  ) +

  scale_fill_gradient(

    low = "#F7FBFF",

    high = "#08306B",

    na.value = "grey85",

    labels = scales::comma

  ) +

  scale_colour_identity() +

  labs(

    title =
      "Expected Primary Endpoint Cases at Precision Threshold",

    subtitle =
      "Cases contributing to the primary VE analysis",

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "True vaccine efficacy",

    fill =
      "Cases"

  ) +

  theme_minimal(
    base_size = 13
  ) +

  theme(

    plot.title.position =
      "plot",

    plot.title =
      element_text(
        face = "bold",
        size = 18
      ),

    axis.title =
      element_text(
        face = "bold"
      ),

    panel.grid =
      element_blank()

  )


print(
  p_cases_heatmap
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "required_endpoint_cases_heatmap.png"
  ),

  p_cases_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)


# ============================================================================
# 17. PRECISION PROBABILITY CURVES FACETED BY SAR
# ============================================================================

p_precision_curves <-

  results_primary %>%

  mutate(

    VE =
      factor(

        paste0(
          true_ve_percent,
          "%"
        ),

        levels =
          paste0(
            TRUE_VES * 100,
            "%"
          )

      ),

    SAR =
      factor(

        paste0(
          sar_percent,
          "%"
        ),

        levels =
          paste0(
            SAR_VALUES * 100,
            "%"
          )

      )

  ) %>%

  ggplot(

    aes(

      x =
        n_rings,

      y =
        probability_precision,

      colour =
        VE

    )

  ) +

  geom_line(
    linewidth = 0.8
  ) +

  geom_hline(

    yintercept =
      TARGET_PROBABILITY,

    linetype =
      "dashed"

  ) +

  facet_wrap(
    ~ SAR
  ) +

  scale_y_continuous(

    labels =
      scales::percent,

    limits =
      c(
        0,
        1
      )

  ) +

  labs(

    title =
      "Probability of Achieving Target VE Precision",

    subtitle =
      paste0(

        "Ring randomisation; facets show placebo direct-contact SAR; target = ±",

        PRECISION_TARGET * 100,

        " percentage points"

      ),

    x =
      "Total number of rings",

    y =
      "Probability of target precision",

    colour =
      "True VE"

  ) +

  theme_minimal() +

  theme(
    plot.title.position =
      "plot"
  )


print(
  p_precision_curves
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "precision_probability_curves_by_sar.png"
  ),

  p_precision_curves,

  width =
    12,

  height =
    9,

  dpi =
    300

)


# ============================================================================
# 18. REQUIRED RINGS VS SAR
# ============================================================================

p_rings_vs_sar <-

  minimum_grid %>%

  mutate(

    VE =
      factor(

        paste0(
          true_ve_percent,
          "%"
        ),

        levels =
          paste0(
            TRUE_VES * 100,
            "%"
          )

      )

  ) %>%

  ggplot(

    aes(

      x =
        sar_percent,

      y =
        n_rings,

      colour =
        VE,

      group =
        VE

    )

  ) +

  geom_line(
    linewidth = 1
  ) +

  geom_point(
    size = 2
  ) +

  scale_x_continuous(

    breaks =
      SAR_VALUES * 100,

    labels =
      function(x) {
        paste0(
          x,
          "%"
        )
      }

  ) +

  labs(

    title =
      "Required Rings as a Function of Secondary Attack Rate",

    subtitle =
      paste0(

        "1:1 ring randomisation; ",

        TARGET_PROBABILITY * 100,

        "% probability of ±",

        PRECISION_TARGET * 100,

        " percentage-point precision"

      ),

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "Minimum number of rings",

    colour =
      "True VE"

  ) +

  theme_minimal() +

  theme(
    plot.title.position =
      "plot"
  )


print(
  p_rings_vs_sar
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "required_rings_vs_sar.png"
  ),

  p_rings_vs_sar,

  width =
    9,

  height =
    6,

  dpi =
    300

)


# ============================================================================
# 19. EXPECTED ENDPOINT CASES AT REQUIRED SAMPLE SIZE
# ============================================================================

p_cases_required <-

  minimum_grid %>%

  filter(
    threshold_reached
  ) %>%

  select(

    sar_percent,

    true_ve_percent,

    mean_placebo_cases,

    mean_vaccine_cases

  ) %>%

  pivot_longer(

    cols =
      c(
        mean_placebo_cases,
        mean_vaccine_cases
      ),

    names_to =
      "trial_arm",

    values_to =
      "expected_cases"

  ) %>%

  mutate(

    trial_arm =
      recode(

        trial_arm,

        mean_placebo_cases =
          "Placebo",

        mean_vaccine_cases =
          "Ervebo"

      ),

    VE =
      paste0(
        true_ve_percent,
        "%"
      )

  ) %>%

  ggplot(

    aes(

      x =
        sar_percent,

      y =
        expected_cases,

      linetype =
        trial_arm,

      colour =
        VE,

      group =
        interaction(
          VE,
          trial_arm
        )

    )

  ) +

  geom_line(
    linewidth = 1
  ) +

  geom_point(
    size = 2
  ) +

  scale_x_continuous(

    breaks =
      SAR_VALUES * 100,

    labels =
      function(x) {
        paste0(
          x,
          "%"
        )
      }

  ) +

  labs(

    title =
      "Expected Endpoint Cases at Required Sample Size",

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "Expected primary endpoint cases",

    colour =
      "True VE",

    linetype =
      "Randomised arm"

  ) +

  theme_minimal() +

  theme(
    plot.title.position =
      "plot"
  )


print(
  p_cases_required
)


ggsave(

  file.path(
    OUTPUT_DIR,
    "expected_cases_at_required_sample_size.png"
  ),

  p_cases_required,

  width =
    9,

  height =
    6,

  dpi =
    300

)


# ============================================================================
# 20. OPTIONAL FINE SEARCH
# ============================================================================

if (
  RUN_FINE_SEARCH
) {


  cat("\n")
  cat("============================================================\n")
  cat("STARTING FINE SEARCH\n")
  cat("============================================================\n")


  fine_results <-

    pmap_dfr(

      scenario_grid,

      function(
    sar,
    true_ve
      ) {


        current_sar <-
          sar


        current_ve <-
          true_ve


        coarse_n <-

          minimum_grid %>%

          filter(

            abs(
              .data$sar -
                current_sar
            ) <
              1e-12,

            abs(
              .data$true_ve -
                current_ve
            ) <
              1e-12

          ) %>%

          pull(
            n_rings
          )


        if (
          length(
            coarse_n
          ) ==
          0 ||
          is.na(
            coarse_n
          )
        ) {

          return(
            tibble()
          )

        }


        lower_n <-

          max(
            10,
            coarse_n -
              FINE_WINDOW
          )


        upper_n <-

          coarse_n +
          FINE_WINDOW


        # Force endpoints to be even

        if (
          lower_n %% 2 != 0
        ) {

          lower_n <-
            lower_n +
            1

        }


        if (
          upper_n %% 2 != 0
        ) {

          upper_n <-
            upper_n +
            1

        }


        fine_candidates <-

          seq(

            from =
              lower_n,

            to =
              upper_n,

            by =
              FINE_STEP

          )


        fine_candidates <-

          fine_candidates[
            fine_candidates %% 2 == 0
          ]


        cat(

          "Fine search SAR =",

          scales::percent(
            sar,
            accuracy = 1
          ),

          "| VE =",

          scales::percent(
            true_ve,
            accuracy = 1
          ),

          "| around",

          coarse_n,

          "rings\n"

        )


        simulate_precision_curve_ring_randomised(

          n_candidates =
            fine_candidates,

          true_ve =
            true_ve,

          sar =
            sar,

          ring_profiles =
            ring_profiles,

          ring_risk_cv =
            RING_RISK_CV,

          primary_analysis =
            PRIMARY_ANALYSIS,

          coc_risk_multiplier =
            COC_RISK_MULTIPLIER,

          nsim =
            FINE_NSIM,

          precision_target =
            PRECISION_TARGET,

          confidence =
            CONFIDENCE_LEVEL

        )

      }

    )


  fine_minimum <-

    fine_results %>%

    filter(

      valid_fraction >=
        MIN_VALID_FRACTION,

      probability_precision >=
        TARGET_PROBABILITY

    ) %>%

    group_by(
      sar,
      true_ve
    ) %>%

    slice_min(

      n_rings,

      n =
        1,

      with_ties =
        FALSE

    ) %>%

    ungroup()


  write_csv(

    fine_results,

    file.path(
      OUTPUT_DIR,
      "fine_search_all_results.csv"
    )

  )


  write_csv(

    fine_minimum,

    file.path(
      OUTPUT_DIR,
      "fine_search_minimum_rings.csv"
    )

  )


  cat("\n")
  cat("============================================================\n")
  cat("FINE SEARCH RESULTS\n")
  cat("============================================================\n\n")


  print(
    fine_minimum,
    n = Inf
  )

}


# ============================================================================
# 21. OPTIONAL SENSITIVITY ANALYSIS:
#     BETWEEN-RING RISK CV
# ============================================================================
#
# This is particularly important for a cluster-randomised design.
#
# It reports the minimum rings required at each:
#
#     SAR x VE x CV
#
# combination.

if (
  RUN_CV_SENSITIVITY
) {


  cat("\n")
  cat("============================================================\n")
  cat("STARTING RING-RISK CV SENSITIVITY ANALYSIS\n")
  cat("============================================================\n")


  cv_grid <-

    crossing(

      ring_risk_cv =
        RING_RISK_CV_VALUES,

      sar =
        SAR_VALUES,

      true_ve =
        TRUE_VES

    )


  cv_results <-

    pmap_dfr(

      cv_grid,

      function(
    ring_risk_cv,
    sar,
    true_ve
      ) {


        cat(

          "CV =",
          ring_risk_cv,

          "| SAR =",
          scales::percent(
            sar,
            accuracy = 1
          ),

          "| VE =",
          scales::percent(
            true_ve,
            accuracy = 1
          ),

          "\n"

        )


        simulate_precision_curve_ring_randomised(

          n_candidates =
            N_CANDIDATES,

          true_ve =
            true_ve,

          sar =
            sar,

          ring_profiles =
            ring_profiles,

          ring_risk_cv =
            ring_risk_cv,

          primary_analysis =
            PRIMARY_ANALYSIS,

          coc_risk_multiplier =
            COC_RISK_MULTIPLIER,

          nsim =
            CV_SENSITIVITY_NSIM,

          precision_target =
            PRECISION_TARGET,

          confidence =
            CONFIDENCE_LEVEL

        ) %>%

          mutate(
            ring_risk_cv =
              ring_risk_cv
          )

      }

    )


  cv_minimum <-

    cv_results %>%

    filter(

      valid_fraction >=
        MIN_VALID_FRACTION,

      probability_precision >=
        TARGET_PROBABILITY

    ) %>%

    group_by(
      ring_risk_cv,
      sar,
      true_ve
    ) %>%

    slice_min(

      n_rings,

      n =
        1,

      with_ties =
        FALSE

    ) %>%

    ungroup()


  write_csv(

    cv_results,

    file.path(
      OUTPUT_DIR,
      "ring_risk_cv_sensitivity_all_results.csv"
    )

  )


  write_csv(

    cv_minimum,

    file.path(
      OUTPUT_DIR,
      "ring_risk_cv_sensitivity_minimum_rings.csv"
    )

  )


  # --------------------------------------------------------------------------
  # Focused plot at the current planning SAR and VE
  # --------------------------------------------------------------------------

  p_cv_planning <-

    cv_minimum %>%

    filter(

      abs(
        sar -
          PLANNING_SAR
      ) <
        1e-12,

      abs(
        true_ve -
          PLANNING_VE
      ) <
        1e-12

    ) %>%

    ggplot(

      aes(

        x =
          ring_risk_cv,

        y =
          n_rings

      )

    ) +

    geom_line(
      linewidth = 1
    ) +

    geom_point(
      size = 2.5
    ) +

    scale_x_continuous(
      breaks =
        RING_RISK_CV_VALUES
    ) +

    labs(

      title =
        "Effect of Between-Ring Heterogeneity on Required Rings",

      subtitle =
        paste0(

          "Planning scenario: SAR = ",
          PLANNING_SAR * 100,

          "%, VE = ",
          PLANNING_VE * 100,

          "%, precision = ±",
          PRECISION_TARGET * 100,
          " pp"

        ),

      x =
        "Coefficient of variation of ring-specific SAR",

      y =
        "Minimum total rings"

    ) +

    theme_minimal() +

    theme(
      plot.title.position =
        "plot"
    )


  print(
    p_cv_planning
  )


  ggsave(

    file.path(
      OUTPUT_DIR,
      "planning_scenario_required_rings_by_ring_risk_cv.png"
    ),

    p_cv_planning,

    width =
      8,

    height =
      5,

    dpi =
      300

  )

}


# ============================================================================
# 22. SAVE SIMULATION SETTINGS
# ============================================================================

simulation_settings <-

  tibble(

    parameter =
      c(

        "Design",

        "Primary analysis population",

        "CoC risk multiplier",

        "Ring-risk CV",

        "Confidence level",

        "Precision target",

        "Target probability",

        "Minimum valid fraction",

        "Monte Carlo simulations per SAR x VE scenario",

        "Minimum candidate rings",

        "Maximum candidate rings",

        "Candidate ring increment",

        "Planning SAR",

        "Planning VE",

        "Random seed",

        "Historical profiles used",

        "Mean eligible participants per historical ring",

        "Median eligible participants per historical ring",

        "Mean direct-contact proportion",

        "Median direct-contact proportion"

      ),

    value =
      c(

        "1:1 ring randomisation",

        PRIMARY_ANALYSIS,

        COC_RISK_MULTIPLIER,

        RING_RISK_CV,

        CONFIDENCE_LEVEL,

        PRECISION_TARGET,

        TARGET_PROBABILITY,

        MIN_VALID_FRACTION,

        N_SIM,

        min(
          N_CANDIDATES
        ),

        max(
          N_CANDIDATES
        ),

        median(
          diff(
            N_CANDIDATES
          )
        ),

        PLANNING_SAR,

        PLANNING_VE,

        SEED,

        nrow(
          ring_profiles
        ),

        mean(
          ring_profiles$eligible_total
        ),

        median(
          ring_profiles$eligible_total
        ),

        mean(
          ring_profiles$prop_direct
        ),

        median(
          ring_profiles$prop_direct
        )

      )

  )


write_csv(

  simulation_settings,

  file.path(
    OUTPUT_DIR,
    "simulation_settings.csv"
  )

)


capture.output(

  sessionInfo(),

  file =
    file.path(
      OUTPUT_DIR,
      "R_session_info.txt"
    )

)


# ============================================================================
# 23. DONE
# ============================================================================

cat("\n")
cat("============================================================\n")
cat("SIMULATION COMPLETE\n")
cat("============================================================\n")

cat("\nOutputs saved in:\n")

cat(
  "  ",
  OUTPUT_DIR,
  "/\n\n",
  sep = ""
)

cat("Main table:\n")
cat("  sample_size_summary_sar_ve.csv\n\n")

cat("Main figure:\n")
cat("  required_rings_heatmap.png\n\n")

cat("Planning scenario:\n")
cat("  planning_scenario_SAR20_VE20.csv\n\n")

cat(
  "Remember: under ring randomisation, RING_RISK_CV is a major driver of ",
  "sample size because exposure heterogeneity is no longer balanced within ring.\n",
  sep = ""
)




library(plotly)

# ============================================================================
# 3-D DESIGN SPACE SHOWN AS HEATMAP SLICES BY RING-RISK CV
# ============================================================================

cv_heatmap_grid <-

  crossing(
    ring_risk_cv = RING_RISK_CV_VALUES,
    sar = SAR_VALUES,
    true_ve = TRUE_VES
  ) %>%

  left_join(
    cv_minimum,
    by = c(
      "ring_risk_cv",
      "sar",
      "true_ve"
    )
  ) %>%

  mutate(

    sar_label =
      paste0(
        sar * 100,
        "%"
      ),

    ve_label =
      paste0(
        true_ve * 100,
        "%"
      ),

    cv_label =
      paste0(
        "Between-ring CV = ",
        ring_risk_cv * 100,
        "%"
      ),

    n_label =
      ifelse(
        is.na(n_rings),
        "> max",
        as.character(n_rings)
      ),

    text_colour =
      ifelse(
        is.na(n_rings),
        "black",
        ifelse(
          n_rings >
            median(n_rings, na.rm = TRUE),
          "white",
          "black"
        )
      )
  )


p_3d_heatmap <-

  cv_heatmap_grid %>%

  ggplot(
    aes(
      x = factor(
        sar_label,
        levels = paste0(
          SAR_VALUES * 100,
          "%"
        )
      ),

      y = factor(
        ve_label,
        levels = rev(
          paste0(
            TRUE_VES * 100,
            "%"
          )
        )
      ),

      fill = n_rings
    )
  ) +

  geom_tile(
    colour = "white",
    linewidth = 0.7
  ) +

  geom_text(
    aes(
      label = n_label,
      colour = text_colour
    ),
    size = 3.2,
    fontface = "bold"
  ) +

  facet_wrap(
    ~ cv_label,
    ncol = 3
  ) +

  scale_fill_gradient(
    low = "#F7FBFF",
    high = "#08306B",
    na.value = "grey85",
    labels = scales::comma
  ) +

  scale_colour_identity() +

  labs(
    title =
      "Required Rings Across SAR, Vaccine Efficacy and Between-Ring Heterogeneity",

    subtitle =
      paste0(
        "1:1 ring randomisation; ",
        TARGET_PROBABILITY * 100,
        "% probability of 95% CI margin ≤ ±",
        PRECISION_TARGET * 100,
        " percentage points"
      ),

    x =
      "Placebo direct-contact secondary attack rate",

    y =
      "True vaccine efficacy",

    fill =
      "Rings required"
  ) +

  theme_minimal(
    base_size = 12
  ) +

  theme(

    plot.title.position =
      "plot",

    plot.title =
      element_text(
        face = "bold",
        size = 17
      ),

    plot.subtitle =
      element_text(
        colour = "grey30",
        margin = margin(
          b = 12
        )
      ),

    strip.text =
      element_text(
        face = "bold",
        size = 11
      ),

    axis.title =
      element_text(
        face = "bold"
      ),

    panel.grid =
      element_blank(),

    legend.position =
      "right"
  )


print(
  p_3d_heatmap
)


ggsave(
  file.path(
    OUTPUT_DIR,
    "required_rings_SAR_VE_CV_heatmap.png"
  ),
  p_3d_heatmap,
  width = 14,
  height = 9,
  dpi = 300
)

# ============================================================================
# INTERACTIVE 3-D DESIGN SPACE
# ============================================================================

plot_3d_data <-

  cv_heatmap_grid %>%

  filter(
    !is.na(n_rings)
  ) %>%

  mutate(

    sar_percent =
      sar * 100,

    ve_percent =
      true_ve * 100,

    cv_percent =
      ring_risk_cv * 100,

    hover_text =
      paste0(
        "SAR: ",
        sar_percent,
        "%<br>",
        "True VE: ",
        ve_percent,
        "%<br>",
        "Between-ring CV: ",
        cv_percent,
        "%<br>",
        "Required rings: ",
        scales::comma(n_rings)
      )

  )


p_3d <-

  plot_ly(

    data =
      plot_3d_data,

    x =
      ~sar_percent,

    y =
      ~ve_percent,

    z =
      ~cv_percent,

    type =
      "scatter3d",

    mode =
      "markers",

    color =
      ~n_rings,

    colors =
      c(
        "#F7FBFF",
        "#08306B"
      ),

    marker =
      list(
        size = 7,
        line = list(
          width = 0.5
        )
      ),

    text =
      ~hover_text,

    hoverinfo =
      "text"

  ) %>%

  layout(

    title =
      paste0(
        "Required Rings Across SAR, VE and Between-Ring Heterogeneity",
        "<br><sup>",
        TARGET_PROBABILITY * 100,
        "% probability of ±",
        PRECISION_TARGET * 100,
        " pp precision</sup>"
      ),

    scene =
      list(

        xaxis =
          list(
            title =
              "Placebo SAR (%)"
          ),

        yaxis =
          list(
            title =
              "True VE (%)"
          ),

        zaxis =
          list(
            title =
              "Between-ring CV (%)"
          )

      )

  )


p_3d


