# Tables grouped by printed heading

Each numbered folder represents one distinct printed table title. Continuation pages are combined in that folder’s `table.csv`. The exact title and PDF page range are in `heading.txt`; `review_issues.csv` lists that table’s review notes.

| PDF pages | Printed table title | Folder | Data rows |
|---|---|---|---:|
| 15–16 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (LHS TUNNEL CH: 0+00 TO 0+300) OUT SIDE OF ROW, FOR CONTROL ROOM BUILDING AREA | [01_lhs_tunnel_control_room](01_lhs_tunnel_control_room/) | 73 |
| 17–20 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (LHS TUNNEL CH: 0+00 TO 0+300) | [02_lhs_tunnel_ch_0_00_to_0_300](02_lhs_tunnel_ch_0_00_to_0_300/) | 160 |
| 21–26 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (RHS TUNNEL CH: 0+00 TO 0+540) HEBBAL LAKE | [03_rhs_tunnel_hebbal_lake](03_rhs_tunnel_hebbal_lake/) | 237 |
| 27–29 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (LAKE, CH: 0+400 TO 0+540) | [04_lake_ch_0_400_to_0_540](04_lake_ch_0_400_to_0_540/) | 85 |
| 30 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH: 0+550 TO 0+700) | [05_ch_0_550_to_0_700](05_ch_0_550_to_0_700/) | 42 |
| 31–32 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH: 0 + 700 TO 1+00) | [06_ch_0_700_to_1_00](06_ch_0_700_to_1_00/) | 77 |
| 33 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH: 1+00 TO 1+300) | [07_ch_1_00_to_1_300](07_ch_1_00_to_1_300/) | 13 |
| 34–37 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH: 1+600 TO 1+800) | [08_ch_1_600_to_1_800](08_ch_1_600_to_1_800/) | 149 |
| 38–39 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH: 1+800 TO 1+900) VERTENARY COLLAGE | [09_veterinary_college_ch_1_800_to_1_900](09_veterinary_college_ch_1_800_to_1_900/) | 74 |
| 40–41 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH:2+000 TO 2+200) BELLARY ROAD | [10_bellary_road_ch_2_000_to_2_200](10_bellary_road_ch_2_000_to_2_200/) | 64 |
| 42–45 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH:2+000 TO 2+200) UAS STAFF QUARTER | [11_uas_staff_quarter_ch_2_000_to_2_200](11_uas_staff_quarter_ch_2_000_to_2_200/) | 159 |
| 46–48 | TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL (CH:2+000 TO 2+200) UAS STAFF QUARTER (For Road Diversion) | [12_uas_staff_quarter_road_diversion_ch_2_000_to_2_200](12_uas_staff_quarter_road_diversion_ch_2_000_to_2_200/) | 103 |

**Total:** 12 headings, 1,236 data rows across PDF pages 15–48.

See [manifest.csv](manifest.csv) for a machine-readable index and [review_issues.csv](review_issues.csv) for all flagged cells and printed numbering irregularities.

Run `python3 scripts/check_tables.py` from the repository root for deterministic checks. The generated [check_findings.csv](check_findings.csv) includes those review notes and additional checks for missing or malformed values, numbering, row order, and page coverage. See the repository [README](../../README.md) for the Emacs issue browser.
