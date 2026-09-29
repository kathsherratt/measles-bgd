# Vaccination and intervention priorities: directions for analysis

Draft for discussion, 30 September 2026. Each direction is framed as the decision it would inform, the data it needs, and whether public data are enough to start.

## Context

- Routine MR1 and MR2 services were disrupted in 2024 and 2025, and one of the two vitamin A rounds in 2025 was missed (UNICEF, WHO).
- 81% of cases are under five and 34% under nine months (WHO SEARO, June), which is below the age of the routine first dose.
- The national outbreak response campaign started on 5 April and in the camps on 26 April. DGHS reports administrative coverage by division of 107 to 117%.
- An administrative coverage above 100% means the target population was underestimated, or doses went outside the target age. Either way, it cannot be read as the share of children protected.

## Directions

| # | Decision it informs | Question | Data | Method | Start with public data? |
|---|---|---|---|---|---|
| 1 | Where and whom to target a follow-up campaign or catch-up | Which districts and birth cohorts have the largest immunity gaps? Gaps are judged by age cohort against who mixes with whom, not against a single 92 to 95% threshold, since a third of cases are too young to be vaccinated routinely. Campaign coverage is treated as uncertain (e.g. 80 to 95%) until a coverage survey exists. | Routine coverage by district and year (DGHS EPI dashboard, DHS), campaign doses by division and city corporation, cases by age and district (natural immunity), births | Cohort immunity profiles: coverage times effectiveness by dose and age, plus infection, minus waning maternal protection. Compare with the WHO measles programmatic risk assessment tool. | Partly: division level, with campaign coverage from DGHS |
| 2 | Whether to add an early dose at 6 months (MR0) in outbreak areas | How many cases and deaths are in infants aged 6 to 8 months, and how many could an early dose avert given lower seroconversion at that age? | Age in months of cases and deaths (line list), maternal antibody waning and seroconversion by age (parameter register) | Age-specific attack rates and CFR; simple averted-burden calculation with uncertainty | No: needs age in months from the line list |
| 3 | Whether the campaign worked, and where it fell short | Did growth fall after the campaign started in each division? Descriptive only: susceptible depletion, the seasonal decline from May and changing case finding all confound it. | Daily cases by division (DGHS), campaign start and coverage by division, camp timing | Growth rate or Rt before and after, using staggered start dates across divisions (the 16 to 20 April footnotes may give phase dates). Confounded by depletion of susceptibles, so a transmission model is the stronger version. | Yes |
| 4 | Whether vaccine failure is part of the problem (cold chain, primary failure, malnutrition) | Is vaccine effectiveness among cases as expected? Only if dose dates exist: controls from a campaign period include vaccine rashes, and vaccine-induced IgM makes recent vaccinees test positive. Needs doses at least 14 days before onset, exclusion of MR doses 6 to 45 days before specimen and of specimens within 3 days of rash, and genotype where available. | Vaccination status of cases (`MeaslesVaccinated`, `DosesMCV`); IgM-negative suspected cases as controls; population coverage by age and district | Test-negative design (lab-confirmed against IgM-negative suspected cases), and the screening method (proportion of cases vaccinated against coverage). Recall-based status and doses given after onset need care. | No: line list |
| 5 | Where to send severity interventions (vitamin A, case management, nutrition screening) | Where will deaths be, rather than cases? | Nowcast cases by district, CFR by age and district (`cfrnow`), wasting prevalence (DHS 2022, IPC), camp nutrition surveys | Expected deaths = cases times CFR(age, district), ranked; wasting as a CFR covariate if individual data exist, otherwise ecological | Partly: division CFR and wasting from public data; ecological only |
| 6 | How long before the next outbreak | When will susceptibles re-accumulate above threshold, under different routine coverage recovery scenarios? | Births, routine coverage, post-outbreak immunity from direction 1 | Age-structured model projecting the susceptible fraction; scenarios for coverage recovery and follow-up campaign timing | Partly |

## Suggested order

1. Direction 3, descriptively, from public data. It answers the question WHO will be asked first ("did the campaign work?"), and builds the division-level growth estimates needed anyway.
2. Direction 5 at division level from public data (hospital outcome ratio, wasting alongside), then districts once data arrive.
3. Direction 1 once routine coverage by district is available (question 19).
4. Direction 2 only if the ministry is actively deciding on MR0 (question 20). WHO already supports an early dose in outbreaks, so the calculation adds most as a local estimate of benefit.
5. Direction 4 only if vaccination dose dates are recorded. Parked otherwise.
6. Direction 6 parked. It needs direction 1.

## Camps

Every direction should be run for camps separately where data allow. The camp campaign started three weeks after the national one, and reported 94% coverage in Cox's Bazar and 99% on Bhasan Char. UNICEF reports more than 15% of children in the camps are malnourished, the highest since 2017, so camps are the setting where direction 5 matters most, and the one with the best denominators (UNHCR registration).

## Questions for WHO

Items 17 to 20 in `who-questions.md`: campaign phases, post-campaign coverage survey, routine coverage by district, and MR0.
