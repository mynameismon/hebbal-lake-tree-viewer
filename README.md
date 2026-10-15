# Hebbal Lake tree-survey data

The [source PDF](Bi-Directional.pdf) is the raw scan. [Initial transcriptions and page notes](data/extracted/README.md) preserve the extraction work. The [tables grouped by printed heading](data/by_heading/README.md) are the edited tables used by the map and checker. Each title has its own folder, `table.csv`, `heading.txt`, and `review_issues.csv`.

## View the map

The [tree survey map](index.html) reads the `data/by_heading` CSVs directly in the browser. Filter by printed heading, action, condition, or tree name/number; select a marker or list row to see the source page and CSV record. Nearby trees share a numbered marker until you zoom in. Records with missing, invalid, or out-of-bounds coordinates appear under **Coordinates to review** instead of on the map. Reload the page after editing a CSV to see the current data.

For a local preview, serve the repository root and open `http://localhost:8765/`:

```sh
python3 -m http.server 8765
```

For GitHub Pages, publish from the repository's root directory on your chosen branch (**Settings → Pages → Build and deployment → Deploy from a branch**). The root `index.html` is the site entry point; `.nojekyll` allows the CSV files to be served as static assets. There is no build step or server component. The map uses Leaflet from a CDN and OpenStreetMap tiles, so the viewer needs internet access. Opening `index.html` as a `file://` URL will not load the CSVs because browsers restrict local `fetch` requests.

## Check the data

Run the deterministic checker from this directory:

```sh
python3 scripts/check_tables.py
```

It writes [check_findings.csv](data/by_heading/check_findings.csv) and [check_findings.json](data/by_heading/check_findings.json). It checks page and serial coverage, row order, continuation rows, blank or malformed values, coordinate bounds, duplicate tree numbers, and consistency between tree condition and action. It flags coordinates outside latitude 12.8–13.2 or longitude 77.3–77.9, and height or canopy diameter above 30 m. These are review thresholds, not automatic corrections. Girth is checked only for blank or nonnumeric values. The report includes the original visual review notes as well as automatic findings; it does not change the transcribed values.

## Review findings in Emacs

Load [hebbal-review.el](lisp/hebbal-review.el) and run `M-x hebbal-review-issues`:

```elisp
(load-file "/path/to/hebbal-lake-data/lisp/hebbal-review.el")
```

The command reruns the checker and opens a list of findings. Press `RET` to show the CSV at the relevant row and the PDF page side by side, with the findings list below. `n` and `p` step through findings and update both views while keeping the list selected. `v` selects the CSV row for editing; `o` shows the PDF page alone; `d` shows the full note and printed heading; `a`, `m`, and `s` filter findings; `g` reruns the checker; `q` restores the previous window layout. With `C-u M-x hebbal-review-issues`, open the last report without rerunning it. When a finding concerns an absent serial number, the CSV view opens the nearest numbered row on that page and tells you it is an approximation.

The PDF pages are scans. Emacs can navigate to the page and show the row identifier, but it cannot reliably highlight the exact printed cell. In GUI Emacs, the PDF view renders the page with `pdftoppm` and rotates it upright with ImageMagick when available. If the PDF is already open in pdf-tools, it uses that buffer instead. The image fallback does not require Ghostscript or DocView.

Rendered pages start fitted to the PDF pane. After zooming in, press `H`/`L` from the findings list or the PDF pane to pan left/right by nearly one pane width. The left/right arrow keys work in the PDF pane as well. In that pane, `SPC` and `DEL` scroll vertically; `s w` fits the whole page again; `s o` shows the original size. The review image keeps your zoom and pan position while you move between findings on the same PDF page.
