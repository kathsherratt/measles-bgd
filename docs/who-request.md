# Data requests and questions for WHO

Email draft, 2 October 2026. Restructured from `who-questions.md`, which stays as the working notes. Reply by item number. Holders are routing hints only.

[Opening: thanks for the call of 30 September; what this list is for.]

If time is short: D1, D2, Q1 and Q2.

## Part 1: Data requests

### Priority: blocks outbreak size and Rt

#### D1. Line-list extract, shared on a regular schedule

- Include: case ID (`MSL BAN-…`); rash onset and notification dates; date each record entered the national database; admission date; outcome and death date; complications including malnutrition; vaccination status and dose dates (`DateLastMCV` is only 0.5% complete); age in months; camp identifier; lab results.
- Also: Have past exports been kept (e.g. weekly since April)? Are the follow-up fields digitised, or is there a death line list? Who holds outcome data, and what key links it to cases? The line list has 89,253 records against 190,510 DGHS suspected cases: are these separate streams (EPI surveillance and the Health Emergency Operation Centre) or cases not yet investigated? How often can an extract be shared, and what can be published in aggregate?
- Holder: WHO country office; IEDCR
- Form: CSV extract
- Aims: 1, 2, 3
- Why: Aim 1: the nowcast needs onset and database-entry dates. Past exports give a reporting triangle; without them notification date stands in for report date. Aim 3: CFR needs outcomes linked to cases (said on the call to be possible). Aim 2: vaccination status and dose dates separate vaccine failure from missed children.

#### D2. Counts before 2 April, by district

- Include, in order of preference:
  - (a) weekly or daily suspected and confirmed cases and deaths by district from October 2025, by rash onset and notification date (routine EPI case-based surveillance);
  - (b) the same from January 2026, with a camp identifier for Cox's Bazar camps;
  - (c) daily DGHS counts by district for 15 March to 7 April, as on the platform after 7 April (suspected, confirmed, admitted, discharged, suspected and confirmed deaths);
  - (d) line-list records with onset before 2 April, if easier to share than aggregates.
- Also: Why 15 March? What started then (case definition, hospital reporting, emergency operations centre), and were earlier cases counted anywhere?
- Holder: DGHS (EPI surveillance; Health Emergency Operation Centre); WHO country office
- Form: CSV
- Aims: 1
- Why: Daily public counts start on 2 April, and the platform puts 15 March to 7 April on one day. Without this period the start date, the speed of take-off and the baseline are not identifiable, and any size estimate has no anchor. First cases were in the camps in January.

#### D3. Weekly camp surveillance (EWARS) measles data, 2026

- Include: weekly counts with a camp identifier. Only week 36 is public, with no camp-level numbers.
- Holder: WHO Cox's Bazar; Health Sector
- Form: CSV or the weekly bulletin tables
- Aims: 1, 3
- Why: The outbreak began in the camps. Without a camp series, Cox's Bazar rates cannot be separated from the camp epidemic, and denominators are unclear.

### Further: aims 2 and 3, laboratory

#### D4. Laboratory and sequence data

- Include: PCR and IgM results with dates; genotype; sequences with collection dates; the phylogenetic analysis (and who ran it); rubella IgM positivity and discard rate by week.
- Holder: IEDCR laboratory; WHO regional reference laboratory
- Form: line-level CSV; sequence metadata; analysis report
- Aims: 1, 3
- Why: Aim 1: a molecular clock can date the undetected period before April, and weekly positivity shows how much of the suspected series is measles. Aim 3: introductions and genotype.

#### D5. Vaccination campaign records

- Include: dates, target ages and doses by district for the April and May rounds and the September mop-up; target population estimates and how they were made; vitamin A given with MR, coverage by division and district.
- Holder: DGHS EPI
- Form: table by district and round
- Aims: 2
- Why: Impact needs the timing and reach of each round. Administrative coverage is 107 to 117%, so the denominator method matters; DGHS releases give division and city corporation only.

#### D6. Routine MR1 and MR2 coverage by district and month, 2023 to 2026

- Holder: DGHS EPI (the EPI dashboard is not reachable from outside Bangladesh)
- Form: CSV export
- Aims: 1, 2
- Why: Pre-outbreak immunity by birth cohort sets the susceptible pool in the size model (aim 1) and the counterfactuals for campaign impact (aim 2).

#### D7. Surveys and community surveillance

- Include: any post-campaign coverage survey (done or planned); any serosurvey; any community-level surveillance in affected areas.
- Holder: WHO country office; UNICEF; IEDCR
- Form: report or dataset, or a note if planned
- Aims: 1, 2
- Why: A coverage survey is the only direct measure of campaign reach (aim 2). Every reported case is hospitalised, so a serosurvey or community data are the only route to infections that never reach hospital (aim 1).

#### D8. Severity and nutrition

- Include: admissions and deaths by age and nutritional status (MUAC, SAM); adenovirus or other co-infection test results.
- Holder: DGHS (hospital reports); IEDCR laboratory
- Form: aggregate table, or columns in the D1 extract
- Aims: 3
- Why: Malnutrition and co-infection burden were reported on the call; CFR by age and nutrition needs them.

#### D9. IEDCR analyses and shared R code

- Include: analyses done so far; a shared repository for R code.
- Holder: IEDCR
- Form: reports; code access
- Aims: 1, 2, 3
- Why: Avoids duplicated work. IEDCR works in R, so our scripts should run on their machines.

## Part 2: Questions

### Priority

#### Q1. Why do the two streams diverge?

WHO monthly surveillance (EPI case investigations) falls from about 21,000 measles cases a month in April and May to 5,234 in July. DGHS hospital admissions stay near 30,000 a month to September. Is case investigation behind, has classification changed, or are more admissions not measles?

- Holder: WHO country office; IEDCR
- Form: call or short written reply
- Aims: 1
- Why: Decides whether the epidemic is declining or has plateaued. Settled before any size estimate.

#### Q2. What changed in classification and testing from June?

Almost every investigated suspect is lab-tested, and epi-linked cases fall from about 16,000 in May to 14 in August. Was this a policy change, and did investigation shrink to what the lab could test? What is the lab sampling policy over time (all suspected cases, or a sample per cluster), and when did it change?

- Holder: WHO country office; IEDCR
- Form: call or short written reply
- Aims: 1
- Why: Part of the fall after May is classification, not transmission. This decides which series to model.

#### Q3. Which hospitals report, and is anyone counted twice?

Are admissions and discharges from all hospitals or sentinel facilities, and has that changed over time? Which units report to the DGHS platform (about 94 a day), and since when? Can a child referred between facilities be counted twice?

- Holder: DGHS (platform team; Health Emergency Operation Centre)
- Form: list of reporting units with start dates, or short reply
- Aims: 1, 3
- Why: A change in reporting units looks like growth or decline. Double counting inflates admissions.

#### Q4. What do the death counts include?

Are the roughly 1,100 deaths hospital deaths, community deaths, or both? Are suspected and confirmed deaths separate (1,003 + 101), as some public totals add them (909 + 100 on 10 September)? Are suspected cases inclusive of confirmed? Are deaths tested?

- Holder: DGHS; WHO country office
- Form: short written reply
- Aims: 1, 3
- Why: The hospital outcome ratio, deaths / (deaths + discharges), and every CFR depend on whether deaths are hospital deaths and whether the two counts overlap.

#### Q5. Are published counts revised?

Are past platform values revised in place? Is a history of edits kept? Is there a record of DGHS revisions (e.g. 18 May, duplicate records at Rajshahi Medical College Hospital)?

- Holder: DGHS (platform team)
- Form: edit log or short reply
- Aims: 1
- Why: The public series treats published days as final. Revisions would mean a hidden reporting delay that the nowcast must model.

#### Q6. Are camp cases in the national totals?

Are camp cases in the national line list, the DGHS totals, both, or neither? Is there a camp or FDMN (Rohingya) identifier in the line list?

- Holder: WHO country office; DGHS
- Form: short written reply
- Aims: 1, 3
- Why: Cox's Bazar rates and the national total cannot be read until camp counting is known.

### Further

#### Q7. What confirms cases other than PCR?

About a thousand cases are PCR-confirmed against 21,392 confirmed by DGHS. Is the rest IgM?

- Holder: IEDCR laboratory; WHO country office
- Aims: 1, 3
- Why: The confirmed share tracks what counts as confirmed, so any analysis on confirmed cases depends on it.

#### Q8. How are rashes after an MR campaign dose handled?

A recent vaccinee can be IgM-positive from the vaccine. Is genotyping done to tell vaccine from wild type?

- Holder: IEDCR laboratory
- Aims: 1, 2
- Why: Affects case counts and any vaccine effectiveness estimate.

#### Q9. Is dengue season affecting the suspected series?

Dengue peaks in September and adds non-measles fever and rash. Is this visible in suspected numbers, and how are such cases classified?

- Holder: IEDCR; WHO country office
- Aims: 1
- Why: Suspected cases will increasingly include non-measles illness.

#### Q10. How is adenovirus co-infection tested, and in whom?

- Holder: IEDCR laboratory
- Aims: 3
- Why: Co-infection was reported on the call; the testing rule decides who is in the denominator.

#### Q11. Is an early MR dose at 6 months (MR0) being given in outbreak areas?

- Holder: DGHS EPI
- Aims: 2
- Why: Changes the susceptible pool among infants; 34% of cases are under nine months.

[Closing: next meeting with the IEDCR director; how to reach you.]
