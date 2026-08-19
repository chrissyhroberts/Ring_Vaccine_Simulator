# ============================================================================
# ERVEBO vs PLACEBO IN BDBV - RING VACCINATION TRIAL SIMULATOR
#
# File: ring_vax_modeller_individual.R
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
# INDIVIDUALLY RANDOMISED RING-BASED TRIAL
#
# SAMPLE-SIZE / PRECISION SIMULATION ACROSS:
#   - SECONDARY ATTACK RATE (SAR)
#   - TRUE VACCINE EFFICACY (VE)
#
# ============================================================================
#
# DESIGN
# ------
# Eligible participants are randomised 1:1 to:
#
#       ERVEBO
#          vs
#       PLACEBO
#
# Randomisation occurs WITHIN each ring.
#
# The base-case primary analysis is restricted to DIRECT CONTACTS,
# because the risk among contacts-of-contacts (CoCs) is uncertain.
#
# CoCs are still counted operationally as people who would need to be
# enrolled/randomised, but they do not contribute to the primary efficacy
# analysis unless PRIMARY_ANALYSIS is changed to "all".
#
#
# PRIMARY DESIGN QUESTION
# -----------------------
# For combinations of:
#
#       Placebo direct-contact SAR = 5%, 10%, ..., 40%
#
# and:
#
#       True VE = 10%, 20%, ..., 60%
#
# how many rings are required so that at least 80% of simulated trials
# obtain a 95% confidence interval for VE with:
#
#       margin of error <= +/- 5 percentage points?
#
#
# IMPORTANT
# ---------
# SAR should ideally represent the risk of the PRIMARY ENDPOINT in placebo
# participants during the period in which the vaccine could plausibly have
# an effect.
#
# It should NOT automatically be interpreted as the total cumulative SAR
# from first exposure to the index case.
#
# For example, if 30% of household contacts ultimately develop disease,
# but many were infected before randomisation, the post-randomisation
# placebo endpoint risk could be considerably lower than 30%.
#
# ============================================================================


# ============================================================================
# 0. PACKAGES
# ============================================================================

library(tidyverse)


# ============================================================================
# 1. USER SETTINGS
# ============================================================================


# ----------------------------------------------------------------------------
# Historical ring-level dataset
# ----------------------------------------------------------------------------

DATA_FILE <- "participants_per_index_R_210621.0311.csv"


# ----------------------------------------------------------------------------
# Output folder
# ----------------------------------------------------------------------------

OUTPUT_DIR <- "simulation_outputs_individual"

dir.create(
  OUTPUT_DIR,
  showWarnings = FALSE
)


# ----------------------------------------------------------------------------
# SECONDARY ATTACK RATE SCENARIOS
# ----------------------------------------------------------------------------
#
# These refer to the PLACEBO risk among DIRECT CONTACTS during the primary
# efficacy window.
#
# Change these values freely.

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


# ----------------------------------------------------------------------------
# TRUE VACCINE EFFICACY SCENARIOS
# ----------------------------------------------------------------------------

TRUE_VES <- c(
  0.10,
  0.20,
  0.30,
  0.40,
  0.50,
  0.60
)


# ----------------------------------------------------------------------------
# PRIMARY ANALYSIS POPULATION
# ----------------------------------------------------------------------------
#
# "direct":
#
#     VE estimated among direct contacts only.
#
# "all":
#
#     VE estimated among direct contacts + contacts-of-contacts.
#
# I recommend "direct" as the initial analysis because we do not yet have
# a defensible estimate of the CoC attack rate.

PRIMARY_ANALYSIS <- "direct"


# ----------------------------------------------------------------------------
# CONTACT-OF-CONTACT RISK
# ----------------------------------------------------------------------------
#
# Used only if PRIMARY_ANALYSIS = "all".
#
# CoC placebo risk is:
#
#     direct contact risk * COC_RISK_MULTIPLIER
#
# Example:
#
# direct contact SAR = 30%
# multiplier = 0.05
#
# CoC risk = 30% * 0.05 = 1.5%
#
# THIS IS A SENSITIVITY PARAMETER, NOT AN EMPIRICAL ESTIMATE.

COC_RISK_MULTIPLIER <- 0.05


# ----------------------------------------------------------------------------
# BETWEEN-RING VARIABILITY
# ----------------------------------------------------------------------------
#
# Different rings will have different transmission intensity.
#
# RING_RISK_CV controls variation around the specified mean SAR.
#
# Examples:
#
# 0.00 = all rings have exactly the same SAR
# 0.25 = modest variation
# 0.50 = substantial variation
# 1.00 = very substantial variation
#
# Because randomisation is WITHIN each ring, both vaccine and placebo
# participants experience the same ring-specific underlying risk.

RING_RISK_CV <- 0.50


# ----------------------------------------------------------------------------
# PRECISION REQUIREMENT
# ----------------------------------------------------------------------------

CONFIDENCE_LEVEL <- 0.95


# Target margin of error:
#
# 0.05 = +/- 5 percentage points
#
# Example:
#
# true VE = 40%
#
# target precision approximately:
#
#       35% ----- 40% ----- 45%

PRECISION_TARGET <- 0.2


# We want at least this probability that a future trial achieves the target
# precision.

TARGET_PROBABILITY <- 0.80


# At least this fraction of simulations must have an estimable VE.

MIN_VALID_FRACTION <- 0.95


# ----------------------------------------------------------------------------
# MONTE CARLO SETTINGS
# ----------------------------------------------------------------------------
#
# 500 is useful for initial exploration.
#
# For protocol-level estimates, increase to at least:
#
#       2000
#
# and preferably:
#
#       5000

N_SIM <- 500


# Candidate number of rings.
#
# Individual randomisation means n_rings does NOT need to be even.

N_CANDIDATES <- seq(
  from = 25,
  to   = 3000,
  by   = 25
)


# Random seed for reproducibility

SEED <- 20260818

set.seed(SEED)


# ----------------------------------------------------------------------------
# OPTIONAL FINE SEARCH
# ----------------------------------------------------------------------------
#
# First run with FALSE.
#
# After obtaining the approximate thresholds, set TRUE and rerun.

RUN_FINE_SEARCH <- FALSE

FINE_STEP <- 5

FINE_WINDOW <- 100

FINE_NSIM <- 3000



# ============================================================================
# 2. READ HISTORICAL DATA
# ============================================================================

df <- read_csv(
  DATA_FILE,
  show_col_types = FALSE
)


cat("\n")
cat("============================================================\n")
cat("HISTORICAL DATA\n")
cat("============================================================\n")

cat(
  "Rows:",
  nrow(df),
  "\n"
)

cat(
  "Columns:",
  ncol(df),
  "\n\n"
)



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
      paste(
        missing_variables,
        collapse = ", "
      )
    )
  )
}


if (!PRIMARY_ANALYSIS %in% c("direct", "all")) {

  stop(
    "PRIMARY_ANALYSIS must be either 'direct' or 'all'."
  )
}



# ============================================================================
# 4. BUILD EMPIRICAL HISTORICAL RING PROFILES
# ============================================================================
#
# We retain two historical properties:
#
#   1. number eligible per ring
#
#   2. proportion of listed contacts who were direct contacts
#
# Each simulated future ring is sampled from this empirical distribution.
#
# Thus we do NOT assume:
#
#   - every ring has 100 people
#   - every ring has the same contact composition
#
# The observed heterogeneity in your historical data is preserved.


ring_profiles <- df %>%

  transmute(

    eligible_total =
      round(
        eligible_for_vaccine
      ),

    direct_contact =
      pmax(
        round(direct_contact),
        0
      ),

    contact_of_contact =
      pmax(
        round(contact_of_contact),
        0
      ),

    listed_contact_total =
      direct_contact +
      contact_of_contact

  ) %>%

  filter(

    !is.na(
      eligible_total
    ),

    eligible_total >= 2,

    !is.na(
      listed_contact_total
    ),

    listed_contact_total > 0

  ) %>%

  mutate(

    prop_direct =
      direct_contact /
      listed_contact_total,

    prop_direct =
      pmin(
        pmax(
          prop_direct,
          0
        ),
        1
      )

  ) %>%

  select(
    eligible_total,
    prop_direct
  )


if (nrow(ring_profiles) < 10) {

  stop(
    "Too few usable historical ring profiles."
  )
}



# ============================================================================
# 5. DESCRIBE HISTORICAL RINGS
# ============================================================================

cat(
  "Usable historical rings:",
  nrow(ring_profiles),
  "\n"
)

cat(
  "Mean eligible participants per ring:",
  round(
    mean(
      ring_profiles$eligible_total
    ),
    1
  ),
  "\n"
)

cat(
  "Median eligible participants per ring:",
  round(
    median(
      ring_profiles$eligible_total
    ),
    1
  ),
  "\n"
)

cat(
  "Mean direct-contact proportion:",
  round(
    mean(
      ring_profiles$prop_direct
    ),
    3
  ),
  "\n"
)

cat(
  "Median direct-contact proportion:",
  round(
    median(
      ring_profiles$prop_direct
    ),
    3
  ),
  "\n\n"
)



# ============================================================================
# 6. HISTORICAL RING-SIZE PLOT
# ============================================================================

p_ring_size <- ring_profiles %>%

  ggplot(
    aes(
      x = eligible_total
    )
  ) +

  geom_histogram(
    bins = 50
  ) +

  geom_vline(

    xintercept =
      median(
        ring_profiles$eligible_total
      ),

    linetype =
      "dashed"

  ) +

  labs(

    title =
      "Historical Distribution of Eligible Participants per Ring",

    subtitle =
      paste0(
        "Median = ",
        round(
          median(
            ring_profiles$eligible_total
          ),
          0
        ),
        "; mean = ",
        round(
          mean(
            ring_profiles$eligible_total
          ),
          0
        )
      ),

    x =
      "Eligible participants per ring",

    y =
      "Number of rings"

  ) +

  theme_minimal() +

  theme(
    plot.title.position =
      "plot"
  )


print(
  p_ring_size
)


ggsave(

  filename =
    file.path(
      OUTPUT_DIR,
      "historical_eligible_ring_size.png"
    ),

  plot =
    p_ring_size,

  width =
    8,

  height =
    5,

  dpi =
    300

)



# ============================================================================
# 7. HISTORICAL DIRECT-CONTACT PROPORTION
# ============================================================================

p_direct_prop <- ring_profiles %>%

  ggplot(
    aes(
      x = prop_direct
    )
  ) +

  geom_histogram(
    bins = 40
  ) +

  geom_vline(

    xintercept =
      median(
        ring_profiles$prop_direct
      ),

    linetype =
      "dashed"

  ) +

  scale_x_continuous(
    labels =
      scales::percent
  ) +

  labs(

    title =
      "Historical Direct-Contact Proportion Within Rings",

    x =
      "Direct contacts / (direct contacts + contacts-of-contacts)",

    y =
      "Number of rings"

  ) +

  theme_minimal() +

  theme(
    plot.title.position =
      "plot"
  )


print(
  p_direct_prop
)


ggsave(

  filename =
    file.path(
      OUTPUT_DIR,
      "historical_direct_contact_proportion.png"
    ),

  plot =
    p_direct_prop,

  width =
    8,

  height =
    5,

  dpi =
    300

)



# ============================================================================
# 8. HELPER FUNCTION:
#    BALANCED 1:1 INDIVIDUAL RANDOMISATION
# ============================================================================

balanced_split <- function(n) {

  n <-
    as.integer(
      n
    )


  # Exactly half for even numbers

  n_vaccine <-
    n %/% 2


  # For odd numbers randomly assign the extra person

  odd <-
    n %% 2


  n_vaccine <-
    n_vaccine +
    odd *
    rbinom(
      length(n),
      size = 1,
      prob = 0.5
    )


  n_placebo <-
    n -
    n_vaccine


  list(

    vaccine =
      n_vaccine,

    placebo =
      n_placebo

  )
}



# ============================================================================
# 9. HELPER FUNCTION:
#    GENERATE RING-SPECIFIC SAR
# ============================================================================
#
# We use a beta distribution.
#
# This means:
#
#     average ring SAR = requested SAR
#
# but individual rings can have higher or lower transmission risk.


rbeta_mean_cv <- function(
    n,
    mean_risk,
    cv
) {


  if (
    mean_risk <= 0 ||
    mean_risk >= 1
  ) {

    stop(
      "mean_risk must be between 0 and 1."
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


  # Beta distribution:
  #
  # mean = mu
  #
  # var =
  #     mu(1-mu)/(phi+1)
  #
  # CV^2 =
  #     variance / mu^2


  phi <-
    (
      (1 - mean_risk) /
        (
          mean_risk *
            cv^2
        )
    ) -
    1


  if (phi <= 0) {

    stop(
      paste0(
        "Mean SAR and CV are incompatible with a beta distribution. ",
        "SAR = ",
        mean_risk,
        "; CV = ",
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

    n =
      n,

    shape1 =
      alpha,

    shape2 =
      beta

  )
}



# ============================================================================
# 10. VE ESTIMATE AND CONFIDENCE INTERVAL
# ============================================================================
#
# Risk ratio:
#
#             risk Ervebo
#     RR = -----------------
#             risk placebo
#
#
# Vaccine efficacy:
#
#     VE = 1 - RR
#
#
# We use the Katz log-risk-ratio CI.
#
# This is preferable to the previous rare-event Poisson approximation
# because some SAR scenarios are as high as 30-40%.


calculate_ve_ci <- function(
    cases_vaccine,
    n_vaccine,
    cases_placebo,
    n_placebo,
    confidence = 0.95
) {


  # A standard log-RR is not estimable when an arm has zero cases.

  valid <-

    cases_vaccine > 0 &

    cases_placebo > 0 &

    n_vaccine >
    cases_vaccine &

    n_placebo >
    cases_placebo


  rr <-
    rep(
      NA_real_,
      length(
        cases_vaccine
      )
    )


  ve_hat <-
    rr


  ci_lower <-
    rr


  ci_upper <-
    rr


  half_width <-
    rr


  if (any(valid)) {


    risk_vaccine <-

      cases_vaccine[valid] /
      n_vaccine[valid]


    risk_placebo <-

      cases_placebo[valid] /
      n_placebo[valid]


    rr[valid] <-

      risk_vaccine /
      risk_placebo


    # Katz SE of log risk ratio

    se_log_rr <-

      sqrt(

        1 /
          cases_vaccine[valid] -

          1 /
          n_vaccine[valid] +

          1 /
          cases_placebo[valid] -

          1 /
          n_placebo[valid]

      )


    z <-

      qnorm(
        1 -
          (
            1 -
              confidence
          ) /
          2
      )


    log_rr <-

      log(
        rr[valid]
      )


    rr_lower <-

      exp(
        log_rr -
          z *
          se_log_rr
      )


    rr_upper <-

      exp(
        log_rr +
          z *
          se_log_rr
      )


    # Transform RR to VE

    ve_hat[valid] <-

      1 -
      rr[valid]


    # Limits reverse because VE = 1 - RR

    ci_lower[valid] <-

      1 -
      rr_upper


    ci_upper[valid] <-

      1 -
      rr_lower


    half_width[valid] <-

      (
        ci_upper[valid] -
          ci_lower[valid]
      ) /
      2

  }


  list(

    valid =
      valid,

    rr =
      rr,

    ve_hat =
      ve_hat,

    ci_lower =
      ci_lower,

    ci_upper =
      ci_upper,

    half_width =
      half_width

  )
}



# ============================================================================
# 11. MAIN SIMULATION FUNCTION
# ============================================================================
#
# Runs one complete precision curve for one:
#
#       SAR x VE
#
# combination.
#
# For efficiency:
#
# 1. Simulate up to max(N_CANDIDATES) rings once.
#
# 2. Calculate cumulative results.
#
# 3. Evaluate every candidate number of rings from the same simulated trial.


# ------------------------------------------------------------------------------
# FUNCTION: simulate_precision_curve
#
# PURPOSE:
# Simulates individually randomised ring-based trials. Individuals within
# each ring are randomised separately, while ring membership is retained to
# account for shared exposure and clustering.
# ------------------------------------------------------------------------------

simulate_precision_curve <- function(

  n_candidates,

  true_ve,

  sar,

  ring_profiles,

  ring_risk_cv = 0.50,

  primary_analysis = "direct",

  coc_risk_multiplier = 0.05,

  nsim = 500,

  precision_target = 0.05,

  confidence = 0.95

) {


  # --------------------------------------------------------------------------
  # Checks
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


  max_n <-

    max(
      n_candidates
    )


  k <-

    length(
      n_candidates
    )



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


  cases_vaccine_mat <-

    matrix(
      NA_real_,
      nrow = nsim,
      ncol = k
    )


  cases_placebo_mat <-

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


  all_randomised_n_mat <-

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


  for (s in seq_len(nsim)) {


    # ------------------------------------------------------------------------
    # A. Sample realistic historical ring profiles
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
    # B. Divide each future ring into direct contacts and CoCs
    # ------------------------------------------------------------------------
    #
    # This preserves the empirical variation in contact composition.


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
    # C. RANDOMISE INDIVIDUALLY 1:1 WITHIN EACH RING
    # ------------------------------------------------------------------------
    #
    # We additionally balance within exposure stratum.
    #
    # Therefore each ring contains approximately:
    #
    #     50% Ervebo direct contacts
    #     50% placebo direct contacts
    #
    # and:
    #
    #     50% Ervebo CoCs
    #     50% placebo CoCs


    direct_split <-

      balanced_split(
        n_direct
      )


    coc_split <-

      balanced_split(
        n_coc
      )


    nv_direct <-

      direct_split$vaccine


    np_direct <-

      direct_split$placebo


    nv_coc <-

      coc_split$vaccine


    np_coc <-

      coc_split$placebo



    # ------------------------------------------------------------------------
    # D. Generate ring-specific PLACEBO direct-contact risks
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



    # ------------------------------------------------------------------------
    # E. Apply true vaccine efficacy
    # ------------------------------------------------------------------------
    #
    # VE is defined on the relative-risk scale:
    #
    # risk_vaccine =
    #     risk_placebo * (1 - VE)


    p_direct_vaccine <-

      p_direct_placebo *
      (
        1 -
          true_ve
      )



    # ------------------------------------------------------------------------
    # F. Contacts-of-contacts
    # ------------------------------------------------------------------------
    #
    # Base assumption:
    #
    # CoC risk is some fraction of direct-contact risk.
    #
    # This does NOT affect the primary analysis when:
    #
    #     PRIMARY_ANALYSIS = "direct"


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
    # G. Generate observed endpoint cases
    # ------------------------------------------------------------------------


    cases_placebo_direct <-

      rbinom(

        n =
          max_n,

        size =
          np_direct,

        prob =
          p_direct_placebo

      )


    cases_vaccine_direct <-

      rbinom(

        n =
          max_n,

        size =
          nv_direct,

        prob =
          p_direct_vaccine

      )


    cases_placebo_coc <-

      rbinom(

        n =
          max_n,

        size =
          np_coc,

        prob =
          p_coc_placebo

      )


    cases_vaccine_coc <-

      rbinom(

        n =
          max_n,

        size =
          nv_coc,

        prob =
          p_coc_vaccine

      )



    # ------------------------------------------------------------------------
    # H. Select primary analysis population
    # ------------------------------------------------------------------------


    if (
      primary_analysis ==
      "direct"
    ) {


      cases_placebo <-

        cases_placebo_direct


      cases_vaccine <-

        cases_vaccine_direct


      n_placebo <-

        np_direct


      n_vaccine <-

        nv_direct


    } else {


      cases_placebo <-

        cases_placebo_direct +
        cases_placebo_coc


      cases_vaccine <-

        cases_vaccine_direct +
        cases_vaccine_coc


      n_placebo <-

        np_direct +
        np_coc


      n_vaccine <-

        nv_direct +
        nv_coc

    }



    # ------------------------------------------------------------------------
    # I. Cumulative totals
    # ------------------------------------------------------------------------


    cum_cases_placebo <-

      cumsum(
        cases_placebo
      )


    cum_cases_vaccine <-

      cumsum(
        cases_vaccine
      )


    cum_n_placebo <-

      cumsum(
        n_placebo
      )


    cum_n_vaccine <-

      cumsum(
        n_vaccine
      )


    cum_all_randomised <-

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



    # Candidate sample-size positions

    idx <-

      n_candidates



    # ------------------------------------------------------------------------
    # J. Calculate VE and CI
    # ------------------------------------------------------------------------


    est <-

      calculate_ve_ci(

        cases_vaccine =
          cum_cases_vaccine[
            idx
          ],

        n_vaccine =
          cum_n_vaccine[
            idx
          ],

        cases_placebo =
          cum_cases_placebo[
            idx
          ],

        n_placebo =
          cum_n_placebo[
            idx
          ],

        confidence =
          confidence

      )



    # ------------------------------------------------------------------------
    # K. Store
    # ------------------------------------------------------------------------


    ve_hat_mat[
      s,
    ] <-

      est$ve_hat


    lower_mat[
      s,
    ] <-

      est$ci_lower


    upper_mat[
      s,
    ] <-

      est$ci_upper


    half_width_mat[
      s,
    ] <-

      est$half_width


    valid_mat[
      s,
    ] <-

      est$valid


    cases_vaccine_mat[
      s,
    ] <-

      cum_cases_vaccine[
        idx
      ]


    cases_placebo_mat[
      s,
    ] <-

      cum_cases_placebo[
        idx
      ]


    analysis_n_mat[
      s,
    ] <-

      cum_n_vaccine[
        idx
      ] +
      cum_n_placebo[
        idx
      ]


    all_randomised_n_mat[
      s,
    ] <-

      cum_all_randomised[
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



  # ==========================================================================
  # SUMMARISE EACH CANDIDATE SAMPLE SIZE
  # ==========================================================================


  map_dfr(

    seq_len(k),

    function(j) {


      valid <-

        valid_mat[
          ,
          j
        ]


      n_valid <-

        sum(
          valid
        )


      # Invalid trials count as FAILURES for the precision criterion.

      precision_success <-

        valid &
        (
          half_width_mat[
            ,
            j
          ] <=
            precision_target
        )


      if (
        n_valid == 0
      ) {


        return(

          tibble(

            sar =
              sar,

            true_ve =
              true_ve,

            n_rings =
              n_candidates[j],

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
                ]
              ),

            mean_all_randomised_participants =
              mean(
                all_randomised_n_mat[
                  ,
                  j
                ]
              ),

            mean_direct_contacts =
              mean(
                direct_n_mat[
                  ,
                  j
                ]
              ),

            mean_coc =
              mean(
                coc_n_mat[
                  ,
                  j
                ]
              ),

            mean_placebo_cases =
              mean(
                cases_placebo_mat[
                  ,
                  j
                ]
              ),

            mean_vaccine_cases =
              mean(
                cases_vaccine_mat[
                  ,
                  j
                ]
              ),

            mean_total_cases =
              mean(
                cases_placebo_mat[
                  ,
                  j
                ] +
                  cases_vaccine_mat[
                    ,
                    j
                  ]
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


        # Fraction of simulations in which VE could be estimated

        valid_fraction =

          mean(
            valid
          ),


        # VE point estimate

        mean_ve =

          mean(
            ve_hat_mat[
              valid,
              j
            ],
            na.rm = TRUE
          ),


        median_ve =

          median(
            ve_hat_mat[
              valid,
              j
            ],
            na.rm = TRUE
          ),


        bias =

          mean(
            ve_hat_mat[
              valid,
              j
            ],
            na.rm = TRUE
          ) -
          true_ve,


        # Median achieved CI margin of error

        median_ci_half_width =

          median(
            half_width_mat[
              valid,
              j
            ],
            na.rm = TRUE
          ),


        # PRIMARY DESIGN CRITERION
        #
        # Invalid simulations count as failures.

        probability_precision =

          mean(
            precision_success
          ),


        # CI coverage among estimable simulations

        coverage =

          mean(

            lower_mat[
              valid,
              j
            ] <=
              true_ve &

              upper_mat[
                valid,
                j
              ] >=
              true_ve,

            na.rm = TRUE

          ),


        # Operational sample sizes

        mean_analysis_participants =

          mean(
            analysis_n_mat[
              ,
              j
            ]
          ),


        mean_all_randomised_participants =

          mean(
            all_randomised_n_mat[
              ,
              j
            ]
          ),


        mean_direct_contacts =

          mean(
            direct_n_mat[
              ,
              j
            ]
          ),


        mean_coc =

          mean(
            coc_n_mat[
              ,
              j
            ]
          ),


        # Expected endpoints

        mean_placebo_cases =

          mean(
            cases_placebo_mat[
              ,
              j
            ]
          ),


        mean_vaccine_cases =

          mean(
            cases_vaccine_mat[
              ,
              j
            ]
          ),


        mean_total_cases =

          mean(

            cases_placebo_mat[
              ,
              j
            ] +

              cases_vaccine_mat[
                ,
                j
              ]

          )

      )

    }

  )

}



# ============================================================================
# 12. RUN THE FULL SAR x VE GRID
# ============================================================================


cat("\n")
cat("============================================================\n")
cat("STARTING SAR x VE SIMULATION\n")
cat("============================================================\n")

cat(
  "Primary population:",
  PRIMARY_ANALYSIS,
  "\n"
)

cat(
  "Ring risk CV:",
  RING_RISK_CV,
  "\n"
)

cat(
  "Precision target: +/-",
  PRECISION_TARGET * 100,
  "percentage points\n"
)

cat(
  "Required probability:",
  TARGET_PROBABILITY * 100,
  "%\n"
)

cat(
  "Monte Carlo simulations per scenario:",
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


      simulate_precision_curve(

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



# ============================================================================
# 13. ADD DISPLAY VARIABLES
# ============================================================================


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



# Save complete simulation curves

write_csv(

  results_primary,

  file.path(
    OUTPUT_DIR,
    "primary_sar_ve_simulation_results.csv"
  )

)



# ============================================================================
# 14. MINIMUM NUMBER OF RINGS FOR EACH SAR x VE COMBINATION
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



# Keep scenarios where maximum N was insufficient

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



# ============================================================================
# 15. PRINT MAIN RESULTS
# ============================================================================


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

      mean_all_randomised_participants,

      mean_analysis_participants,

      mean_placebo_cases,

      mean_vaccine_cases,

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
    "At least one SAR x VE scenario did not reach the precision target.\n"
  )

  cat(
    "Increase max(N_CANDIDATES) and rerun.\n\n"
  )

}



# ============================================================================
# 16. CLEAN REPORTING TABLE
# ============================================================================


summary_table <-

  minimum_grid %>%

  transmute(

    `Placebo direct-contact SAR (%)` =
      sar_percent,

    `True VE (%)` =
      true_ve_percent,

    `Minimum rings` =
      n_rings,

    `Total randomised participants` =
      round(
        mean_all_randomised_participants,
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

    `Expected placebo cases` =
      round(
        mean_placebo_cases,
        1
      ),

    `Expected Ervebo cases` =
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
# 17. HEATMAP:
#     NUMBER OF RINGS REQUIRED
# ============================================================================

p_rings_heatmap <-

  minimum_grid %>%

  mutate(

    sar_label = paste0(sar_percent, "%"),

    ve_label = paste0(true_ve_percent, "%"),

    n_label = ifelse(
      is.na(n_rings),
      "> max",
      as.character(n_rings)
    ),

    # Used only to decide whether label should be black or white
    text_colour = ifelse(
      is.na(n_rings),
      "black",
      ifelse(
        n_rings > median(n_rings, na.rm = TRUE),
        "white",
        "black"
      )
    )

  ) %>%

  ggplot(
    aes(
      x = factor(
        sar_label,
        levels = paste0(SAR_VALUES * 100, "%")
      ),

      y = factor(
        ve_label,
        levels = rev(paste0(TRUE_VES * 100, "%"))
      ),

      fill = n_rings
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
    size = 4.2,
    fontface = "bold"
  ) +

  # Clean sequential colour scale
  scale_fill_viridis_c(
    option = "E",          # cividis
    direction = -1,        # high ring requirement = darker
    na.value = "grey85",
    labels = scales::comma
  ) +

  scale_colour_identity() +

  labs(
    title = "Rings Required for Target VE Precision",

    subtitle = paste0(
      "Individual 1:1 randomisation within rings; ",
      TARGET_PROBABILITY * 100,
      "% probability of 95% CI margin ≤ ±",
      PRECISION_TARGET * 100,
      " percentage points"
    ),

    x = "Placebo direct-contact secondary attack rate",

    y = "True vaccine efficacy",

    fill = "Rings required"
  ) +

  coord_fixed(ratio = 0.65) +

  theme_minimal(base_size = 13) +

  theme(
    plot.title.position = "plot",

    plot.title = element_text(
      face = "bold",
      size = 18
    ),

    plot.subtitle = element_text(
      size = 12,
      colour = "grey30",
      margin = margin(b = 15)
    ),

    axis.title = element_text(
      face = "bold"
    ),

    axis.text = element_text(
      colour = "grey20"
    ),

    panel.grid = element_blank(),

    legend.position = "right"
  )

p_rings_heatmap



print(
  p_rings_heatmap
)



ggsave(

  filename =
    file.path(
      OUTPUT_DIR,
      "required_rings_heatmap.png"
    ),

  plot =
    p_rings_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)



# ============================================================================
# 18. HEATMAP:
#     TOTAL NUMBER OF PARTICIPANTS RANDOMISED
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
          mean_all_randomised_participants
        ),

        "> max",

        scales::comma(
          round(
            mean_all_randomised_participants,
            0
          )
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
        mean_all_randomised_participants

    )

  ) +

  geom_tile() +

  geom_text(

    aes(
      label =
        n_label
    ),

    size =
      3.4

  ) +

  labs(

    title =
      "Total Randomised Participants Required",

    subtitle =
      "Includes direct contacts and contacts-of-contacts in enrolled rings",

    x =
      "Placebo direct-contact SAR",

    y =
      "True vaccine efficacy",

    fill =
      "Participants"

  ) +

  theme_minimal() +

  theme(

    plot.title.position =
      "plot",

    panel.grid =
      element_blank()

  )



print(
  p_participants_heatmap
)



ggsave(

  filename =
    file.path(
      OUTPUT_DIR,
      "required_participants_heatmap.png"
    ),

  plot =
    p_participants_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)



# ============================================================================
# 19. HEATMAP:
#     EXPECTED ENDPOINT CASES
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

  geom_tile() +

  geom_text(

    aes(
      label =
        cases_label
    ),

    size =
      4

  ) +

  labs(

    title =
      "Expected Primary Endpoint Cases at Precision Threshold",

    subtitle =
      "Cases contributing to the primary VE analysis",

    x =
      "Placebo direct-contact SAR",

    y =
      "True vaccine efficacy",

    fill =
      "Cases"

  ) +

  theme_minimal() +

  theme(

    plot.title.position =
      "plot",

    panel.grid =
      element_blank()

  )



print(
  p_cases_heatmap
)



ggsave(

  filename =
    file.path(
      OUTPUT_DIR,
      "required_endpoint_cases_heatmap.png"
    ),

  plot =
    p_cases_heatmap,

  width =
    10,

  height =
    6,

  dpi =
    300

)



# ============================================================================
# 20. REQUIRED RINGS vs SAR
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
        "Individual randomisation; ",
        TARGET_PROBABILITY * 100,
        "% probability of +/-",
        PRECISION_TARGET * 100,
        " percentage-point precision"
      ),

    x =
      "Placebo direct-contact SAR",

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

  filename =
    file.path(
      OUTPUT_DIR,
      "required_rings_vs_sar.png"
    ),

  plot =
    p_rings_vs_sar,

  width =
    9,

  height =
    6,

  dpi =
    300

)



# ============================================================================
# 21. PRECISION PROBABILITY CURVES BY SAR
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
        "Each panel gives placebo direct-contact SAR; ",
        "target CI margin = +/-",
        PRECISION_TARGET * 100,
        " percentage points"
      ),

    x =
      "Number of rings",

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

  filename =
    file.path(
      OUTPUT_DIR,
      "precision_probability_curves_by_sar.png"
    ),

  plot =
    p_precision_curves,

  width =
    12,

  height =
    9,

  dpi =
    300

)



# ============================================================================
# 22. EXPECTED CASES AT REQUIRED SAMPLE SIZE
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
      "Placebo direct-contact SAR",

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

  filename =
    file.path(
      OUTPUT_DIR,
      "expected_cases_at_required_sample_size.png"
    ),

  plot =
    p_cases_required,

  width =
    9,

  height =
    6,

  dpi =
    300

)



# ============================================================================
# 23. OPTIONAL FINE SEARCH
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
          ) == 0 ||
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
            5,
            coarse_n -
              FINE_WINDOW
          )


        upper_n <-

          coarse_n +
          FINE_WINDOW


        fine_candidates <-

          seq(

            from =
              lower_n,

            to =
              upper_n,

            by =
              FINE_STEP

          )


        cat(

          "Fine search: SAR =",
          scales::percent(
            sar,
            accuracy = 1
          ),

          "| VE =",
          scales::percent(
            true_ve,
            accuracy = 1
          ),

          "| coarse estimate =",
          coarse_n,
          "rings\n"

        )


        simulate_precision_curve(

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
# 24. SAVE SIMULATION SETTINGS
# ============================================================================


simulation_settings <-

  tibble(

    parameter =
      c(

        "Primary analysis population",

        "CoC risk multiplier",

        "Ring risk CV",

        "Confidence level",

        "Precision target",

        "Target probability",

        "Minimum valid fraction",

        "Monte Carlo simulations per scenario",

        "Minimum candidate rings",

        "Maximum candidate rings",

        "Candidate ring increment",

        "Random seed",

        "Number historical ring profiles",

        "Mean eligible participants per ring",

        "Median eligible participants per ring",

        "Mean direct-contact proportion",

        "Median direct-contact proportion"

      ),

    value =
      c(

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



# ============================================================================
# 25. SAVE R SESSION INFORMATION
# ============================================================================


capture.output(

  sessionInfo(),

  file =
    file.path(
      OUTPUT_DIR,
      "R_session_info.txt"
    )

)



# ============================================================================
# 26. DONE
# ============================================================================


cat("\n")
cat("============================================================\n")
cat("SIMULATION COMPLETE\n")
cat("============================================================\n\n")


cat(
  "Outputs saved in:\n",
  OUTPUT_DIR,
  "\n\n"
)


cat(
  "MAIN NUMERIC OUTPUT:\n",
  file.path(
    OUTPUT_DIR,
    "sample_size_summary_sar_ve.csv"
  ),
  "\n\n"
)


cat(
  "MAIN FIGURE:\n",
  file.path(
    OUTPUT_DIR,
    "required_rings_heatmap.png"
  ),
  "\n\n"
)


cat(
  "Interpret SAR as the placebo risk of the primary endpoint ",
  "during the efficacy window.\n"
)
