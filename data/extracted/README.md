# Hebbal tree survey CSVs

These CSVs transcribe the data tables on PDF pages 15–48 of [Bi-Directional.pdf](../../Bi-Directional.pdf). Each distinct printed table heading has its own CSV. `source_page` is the PDF page number, starting at 1. Values follow the scan, including printed spelling and numbering irregularities. Empty cells in the source remain empty. Cells that cannot be read confidently are left empty and listed in [issues.csv](issues.csv).

| PDF pages | Table section | CSV | Data rows | Printed total |
|---|---|---|---:|---:|
| 15–16 | LHS tunnel, outside ROW, control room building area | [CSV](tree_survey_lhs_control_room_outside_row.csv) | 73 | 73 |
| 17–20 | LHS tunnel, CH 0+00 to 0+300 | [CSV](tree_survey_lhs_tunnel_ch_0_000_to_0_300.csv) | 160 | 124 |
| 21–26 | RHS tunnel, CH 0+00 to 0+540, Hebbal Lake | [CSV](tree_survey_rhs_tunnel_hebbal_lake_ch_0_000_to_0_540.csv) | 237 | 165 |
| 27–29 | Lake, CH 0+400 to 0+540 | [CSV](tree_survey_lake_ch_0_400_to_0_540.csv) | 85 | 85 |
| 30 | CH 0+550 to 0+700 | [CSV](tree_survey_ch_0_550_to_0_700.csv) | 42 | 42 |
| 31–32 | CH 0 + 700 to 1+00 | [CSV](tree_survey_ch_0_700_to_1_00.csv) | 77 | 77 |
| 33 | CH 1+00 to 1+300 | [CSV](tree_survey_ch_1_00_to_1_300.csv) | 13 | 13 |
| 34–37 | CH 1+600 to 1+800 | [CSV](tree_survey_ch_1_600_to_1_800.csv) | 149 | 149 |
| 38–39 | CH 1+800 to 1+900, “VERTENARY COLLAGE” | [CSV](tree_survey_ch_1_800_to_1_900_veterinary_college.csv) | 74 | 74 |
| 40–41 | CH 2+000 to 2+200, Bellary Road | [CSV](tree_survey_hebbal_cut_cover_ch_2_000_2_200_bellary_road.csv) | 64 | 64 |
| 42–45 | CH 2+000 to 2+200, UAS Staff Quarter | [CSV](tree_survey_hebbal_cut_cover_ch_2_000_2_200_uas_staff_quarter.csv) | 159 | 159 |
| 46–48 | CH 2+000 to 2+200, UAS Staff Quarter (For Road Diversion) | [CSV](tree_survey_hebbal_cut_cover_ch_2_000_2_200_uas_staff_quarter_for_road_diversion.csv) | 103 | 103 |

**Totals:** 12 tables, 34 PDF pages, 1,236 data rows. The data-row count exceeds some printed totals because letter-suffixed tree numbers appear on separate rows beneath a shared serial number. The printed headings on pages 31–33 really use `1+00`; no zero was supplied. The page 38–39 heading spells “VERTENARY COLLAGE” in the scan.

The CSVs use a consistent 13-column layout, except the page 34–37 table calls its last column `location_ch` to reflect the printed `LOCATION(CH:)` header. [issues.csv](issues.csv) lists uncertain cells, source-empty cells worth noting, and numbering gaps for review. The `parts_*` folders retain the agents' page-batch working files and page maps.
