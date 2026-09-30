# Questions for WHO and IEDCR

First asked at the WHO call on 30 September 2026. Updated after it for the next meeting, when the IEDCR director joins. Ordered by aim 1 first; the aim 2 and 3 data list is in `first-steps.md`.

## Answered on the call

| Question | Answer | Follow-up |
|---|---|---|
| Are admissions all hospitals, and are cases community or hospital? (7) | All reported cases are hospitalised | Which hospitals report, and has that changed over time? |
| Are suspected and confirmed deaths separate? (6) | About 1,100 deaths in total, which matches 1,003 suspected + 101 confirmed | Confirm the two counts are disjoint |
| Can cases be linked to outcomes? (2, 3) | Not yet; may be possible | Who holds the outcome data, and what key links them? |
| When did the outbreak start? | First case January in the Cox's Bazar camps; spread from March and April; WHO informed in April | Any case data from January to March? |

## New from the call

- IEDCR analyses: can we see what has been done, and work on shared R code?
- PCR: about a thousand PCR-confirmed cases against 21,392 confirmed by DGHS. What confirms the rest (IgM), and can PCR and genotype results be shared?
- The phylogenetic analysis: who ran it, and are sequences with collection dates available?
- Adenovirus: how is co-infection being tested, and in whom?
- September mop-up campaign: dates, target ages and doses by district.
- Any serosurvey, or community-level surveillance, in affected areas?
- Two streams, two epidemics: WHO monthly surveillance (EPI case investigations) falls from about 21,000 measles cases a month in April and May to 5,234 in July, while DGHS hospital admissions stay near 30,000 a month to September. Why? Is case investigation behind, is classification changing (epi-linked cases drop from about 16,000 in May to 14 in August), or are more admissions not measles?
- WHO monthly data: from June almost every investigated suspect is lab-tested and epi-linking all but stops. Was this a policy change, and did case investigation shrink to what the lab could test?
- Hospital counts: can a child referred between facilities be counted twice? Are deaths tested?
- The DGHS monitoring platform: which units report (about 94 a day), since when, and are past values revised in place? Is a history of edits kept?

## Line list: nowcasting and CFR

1. Vintages. Have past line-list exports been kept, e.g. weekly since April? Is there a date each record entered the national database? Either gives a reporting triangle; without them, notification date stands in for report date.
2. Outcome. Are the form's follow-up fields digitised: admission date, complications (including malnutrition), outcome, date of death? If not, is there a death line list or death review dataset?
3. Linkage. Can the case ID (`MSL BAN-…`) be included, so deaths and lab results can be joined to cases?
4. Coverage. The line list has 89,253 records; DGHS reports 190,510 suspected cases. Are these separate streams (EPI surveillance and the Health Emergency Operation Centre), or cases not yet investigated?
5. Frequency and terms. How often could an extract be shared, and what can be published in aggregate?

## Definitions in the DGHS releases

6. Are suspected cases and deaths inclusive of confirmed ones, or separate? Some public totals add them (909 + 100 = 1,009 deaths on 10 September).
7. Are admissions and discharges from all hospitals, or sentinel facilities? Are the deaths hospital deaths, community deaths, or both? A hospital outcome ratio, deaths / (deaths + discharges), needs to know.
8. Is there a record of DGHS revisions (e.g. 18 May, duplicate records at Rajshahi Medical College Hospital)?

## Lab and case classification

9. Lab sampling policy over time: all suspected cases, or a sample per cluster? When did it change?
10. How are rashes after an MR campaign dose handled? A recent vaccinee can be IgM-positive from the vaccine, so this matters for both case counts and any vaccine effectiveness estimate. Is the campaign dose date recorded (only 0.5% have `DateLastMCV`)? Is genotyping done?
11. Differential diagnosis: rubella IgM positivity and the discard rate by week. Dengue season (September) will add non-measles fever and rash to the suspected series.

## Camps

12. Are camp cases in the national line list, the DGHS totals, both or neither?
13. Can the weekly camp surveillance (EWARS) measles data for 2026 be shared? Only week 36 is public, and it has no camp-level numbers.
14. Is there a camp or FDMN (Rohingya) identifier in the line list?

## Severity and nutrition

15. Hospital admissions and deaths by age and nutritional status (MUAC, SAM)?
16. Vitamin A given with MR in the campaign: coverage by division and district.

## Vaccination

17. Campaign dates by division and district (phases).
18. Has a post-campaign coverage survey been done or planned? Administrative coverage is 107 to 117%, so it cannot be read as protection.
19. Routine MR1 and MR2 coverage by district and month (the DGHS EPI dashboard is not reachable from outside Bangladesh).
20. Is an early MR dose at 6 months (MR0) being given in outbreak areas?
