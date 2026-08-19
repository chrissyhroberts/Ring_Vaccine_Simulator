# Ring Vaccination Trial Design Simulator

Simulation framework for evaluating alternative ring vaccination trial designs.

The primary output is the estimated number of rings required to achieve a specified level of statistical precision under each trial design.

**Authors**
- Chrissy h. Roberts
- Anton Camacho

**Licence**
MIT Licence

---

## Overview

This repository contains simulation code for evaluating ring vaccination trial designs under different randomisation strategies:

1. **Individual randomisation within rings**
2. **Ring-level (cluster) randomisation**

The models simulate trial performance under different assumptions about:

- ring size
- secondary attack rate (SAR)
- variation in ring-level transmission risk
- vaccine efficacy (VE)
- trial precision requirements

The framework is designed for study design and power estimation for ring vaccination studies.

---

## Important note on data availability

The empirical outbreak ring dataset used to parameterise these models is **not public information**.

The code is shared for transparency, methodological review, and reproducibility of the modelling approach. However:

> The scripts will not run without a compatible input dataset.

Users will need either:

1. Access to the original outbreak dataset, or
2. A simulated dataset following the structure described below.

The repository therefore contains the modelling framework, but not the confidential underlying outbreak data.

---

## Model concept

A vaccination ring is defined around an index case.

The model uses historical outbreak data to reproduce realistic ring structures:

```
Index case
    |
    +-- Primary contact 1
    +-- Primary contact 2
    +-- Primary contact 3
```

The primary analysis population is **direct/primary contacts**.

The core empirical input is:

- `eligible_for_vaccine` — the number of eligible contacts contributing to ring size
- `direct_contact` — number of primary contacts
- `contact_of_contact` — retained in the input structure but excluded from the primary-contact analysis population unless explicitly enabled

The models do not import observed transmission chains. Instead, infection outcomes are simulated within outbreak-derived ring structures using specified SAR, ring-risk heterogeneity, and vaccine efficacy assumptions.

---

# Model types

## Individual randomisation

In the individual randomisation model:

- each index case generates a ring
- individuals within each ring are randomised to vaccine or control
- outcomes are analysed at the individual level
- ring membership is retained because contacts within a ring share exposure risk

The ring is therefore the exposure structure, but not the unit of randomisation.

---

## Ring randomisation

In the ring randomisation model:

- each index case generates a ring
- the complete ring is randomised to vaccine or control
- the ring is the unit of randomisation and comparison

Each ring contributes one randomisation unit.

---

# Input dataset structure

The confidential outbreak dataset should contain one row per contact.

Required variables:

| Variable | Description |
|---|---|
| `ring_id` | Unique identifier for the vaccination ring |
| `index_case_id` | Identifier for the associated index case |
| `eligible_for_vaccine` | Number/indicator used to define eligible vaccination population |
| `direct_contact` | Number/indicator for primary/direct contacts |
| `contact_of_contact` | Number/indicator for secondary contacts |

The scripts validate the presence of these variables before running.

Example simulated input:

```csv
ring_id,index_case_id,eligible_for_vaccine,direct_contact,contact_of_contact
1,1001,1,1,0
1,1001,1,1,0
1,1001,1,1,0
2,1002,1,1,0
2,1002,1,1,0
```

This represents two rings containing three and two primary contacts respectively.

---

# Outputs

The models generate simulated trial datasets and summary results describing the expected performance of each trial design.

Outputs include:

## Trial-level simulation results

For each simulated trial, the models record:

- number of vaccination rings recruited
- number of eligible primary contacts enrolled
- allocation to vaccine and control groups
- simulated infection outcomes
- observed vaccine effect estimates
- whether the trial achieved the predefined precision target

These outputs allow assessment of the probability that a proposed trial design will meet its objectives.

---

## Design performance summaries

Across repeated simulations, the models summarise:

- required number of rings
- required number of participants
- number of expected infection events
- probability of achieving target precision
- distribution of estimated vaccine efficacy
- uncertainty around trial estimates

---

## Comparison between designs

The framework allows direct comparison of:

### Individual randomisation

Outputs describe:

- number of rings required to recruit sufficient individuals
- expected number of vaccinated and control participants
- precision of individual-level vaccine effect estimates

### Ring randomisation

Outputs describe:

- number of rings required as independent randomisation units
- expected number of participants within vaccinated and control rings
- impact of ring-level clustering on precision

---

## Interpretation

The outputs are intended to support trial design decisions by showing how alternative randomisation strategies perform under realistic outbreak conditions.

They are not forecasts of outbreak size or transmission. They are simulations of trial performance under specified epidemiological assumptions.

---

# Creating a simulated dataset

A minimal simulated dataset can be created by sampling realistic ring sizes.

Example:

```r
n_rings <- 500

ring_sizes <- sample(
  1:20,
  n_rings,
  replace = TRUE
)

simulated_contacts <- data.frame(
  ring_id = rep(seq_len(n_rings), ring_sizes)
)

simulated_contacts$index_case_id <-
  simulated_contacts$ring_id + 1000

simulated_contacts$eligible_for_vaccine <- 1
simulated_contacts$direct_contact <- 1
simulated_contacts$contact_of_contact <- 0
```

A more realistic simulation should reproduce:

- the observed distribution of `eligible_for_vaccine`
- variation in ring sizes between index cases
- the observed proportion of direct contacts

---

# Running the models

Main scripts:

```
ring_vax_modeller_individual.R
ring_vax_modeller_cluster.R
```

Each script contains:

1. Configuration parameters at the top
2. Input data processing
3. Ring generation
4. Randomisation
5. Transmission simulation
6. VE estimation and precision calculations

Configuration options should be modified only in the configuration section at the top of each script.

---

# Reproducibility

The models use stochastic simulation.

Set a random seed before running simulations:

```r
set.seed(123)
```

---

# Citation

If you use or adapt this framework, please cite:

Roberts CH and Camacho A.

Ring vaccination trial design simulation framework.

---

# Licence

MIT License

Copyright (c) Chrissy h. Roberts and Anton Camacho
