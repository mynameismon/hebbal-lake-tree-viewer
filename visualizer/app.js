import { parseCsv } from "./csv.js";

const $ = selector => document.querySelector(selector);
const bounds = { south: 12.8, north: 13.2, west: 77.3, east: 77.9 };
const state = { headings: [], rows: [], filtered: [], selected: null, visibleLimit: 80, markers: null, map: null };
const ui = {
  status: $("#status"), heading: $("#heading"), action: $("#action"), condition: $("#condition"),
  search: $("#search"), selected: $("#selected"), results: $("#results-list"),
  unmapped: $("#unmapped"), unmappedList: $("#unmapped-list"), more: $("#show-more"),
};

function el(tag, className, content) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (content !== undefined) node.textContent = content;
  return node;
}

function headingLabel(heading) {
  return heading.replace(/^TREE SURVEY DETAILS OF HEBBAL CUT AND COVER TWIN TUNNEL\s*/i, "").trim() || heading;
}

function category(action) {
  const value = action.trim().toLowerCase();
  if (value.includes("transplant")) return "transplanting";
  if (value.includes("cut")) return "cutting";
  return "other";
}

function actionLabel(action) {
  const key = category(action);
  return key === "other" ? (action.trim() || "Unspecified") : key[0].toUpperCase() + key.slice(1);
}

function conditionLabel(condition) {
  return condition.trim() || "Unspecified";
}

function coordinateStatus(row) {
  if (!row.latitude.trim() || !row.longitude.trim()) return "Missing coordinate";
  const lat = Number(row.latitude);
  const lon = Number(row.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return "Invalid coordinate";
  if (lat < bounds.south || lat > bounds.north || lon < bounds.west || lon > bounds.east) return "Outside survey bounds";
  return "";
}

async function fetchCsv(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return parseCsv(await response.text());
}

async function loadData() {
  const headings = await fetchCsv("./data/by_heading/manifest.csv");
  const groups = await Promise.all(headings.map(async heading => {
    const path = `./data/by_heading/${encodeURIComponent(heading.group)}/table.csv`;
    const rows = await fetchCsv(path);
    return rows.map((row, index) => ({
      ...row, heading: heading.printed_heading, group: heading.group, path,
      csvRecord: index + 2, key: `${heading.group}:${index + 2}`, issue: coordinateStatus(row),
      lat: Number(row.latitude), lon: Number(row.longitude),
      actionKey: category(row.cutting_transplanting || ""),
      conditionKey: conditionLabel(row.condition_of_tree || "").toLowerCase(),
    }));
  }));
  state.headings = headings;
  state.rows = groups.flat();
}

function setOptions(select, options, labeler = value => value) {
  const prior = select.value;
  select.replaceChildren(select.firstElementChild);
  for (const value of options) {
    const option = el("option", "", labeler(value));
    option.value = value;
    select.append(option);
  }
  select.value = prior;
}

function setupFilters() {
  setOptions(ui.heading, state.headings.map(h => h.group), group => {
    const heading = state.headings.find(h => h.group === group);
    return `${group.slice(0, 2)} · ${headingLabel(heading.printed_heading)}`;
  });
  setOptions(ui.action, [...new Set(state.rows.map(row => row.actionKey))].sort(), action => action === "other" ? "Other / unknown" : actionLabel(action));
  setOptions(ui.condition, [...new Set(state.rows.map(row => row.conditionKey))].sort(), value => value[0].toUpperCase() + value.slice(1));
}

function filterRows() {
  const query = ui.search.value.trim().toLowerCase();
  state.filtered = state.rows.filter(row => {
    if (ui.heading.value && row.group !== ui.heading.value) return false;
    if (ui.action.value && row.actionKey !== ui.action.value) return false;
    if (ui.condition.value && row.conditionKey !== ui.condition.value) return false;
    if (!query) return true;
    return [row.tree_no, row.sl_no, row.tree_english_common_name, row.botanical_name, row.location, row.location_ch]
      .some(value => (value || "").toLowerCase().includes(query));
  });
  $("#result-count").textContent = state.filtered.length.toLocaleString();
  $("#mapped-count").textContent = state.filtered.filter(row => !row.issue).length.toLocaleString();
  $("#unmapped-count").textContent = state.filtered.filter(row => row.issue).length.toLocaleString();
  $("#list-caption").textContent = `${Math.min(state.visibleLimit, state.filtered.length)} shown`;
  renderRows();
  renderUnmapped();
  renderMarkers();
  if (state.selected && !state.filtered.includes(state.selected)) {
    state.selected = null;
    ui.selected.hidden = true;
  }
}

function treeName(row) {
  return row.tree_english_common_name?.trim() || row.botanical_name?.trim() || "Unnamed tree";
}

function rowButton(row, compact = false) {
  const button = el("button", `tree-row ${compact ? "compact" : ""}`);
  button.type = "button";
  const title = el("span", "tree-row-title", treeName(row));
  const meta = el("span", "tree-row-meta", `Tree ${row.tree_no || "—"} · ${row.group.slice(0, 2)} · PDF p. ${row.source_page || "?"}`);
  button.append(title, meta);
  if (!compact) button.append(el("span", `action-tag ${row.actionKey}`, actionLabel(row.cutting_transplanting || "")));
  button.addEventListener("click", () => selectRow(row, true));
  return button;
}

function renderRows() {
  ui.results.replaceChildren(...state.filtered.slice(0, state.visibleLimit).map(row => rowButton(row)));
  if (!state.filtered.length) ui.results.append(el("p", "empty", "No rows match these filters."));
  ui.more.hidden = state.filtered.length <= state.visibleLimit;
}

function renderUnmapped() {
  const missing = state.filtered.filter(row => row.issue);
  ui.unmapped.hidden = !missing.length;
  ui.unmappedList.replaceChildren(...missing.map(row => {
    const wrapper = el("div", "unmapped-item");
    wrapper.append(rowButton(row, true), el("span", "issue", `${row.issue}: ${row.latitude || "—"}, ${row.longitude || "—"}`));
    return wrapper;
  }));
}

function detail(label, value) {
  const item = el("div", "detail-item");
  item.append(el("dt", "", label), el("dd", "", value || "—"));
  return item;
}

function selectRow(row, navigate) {
  state.selected = row;
  ui.selected.hidden = false;
  ui.selected.replaceChildren();
  ui.selected.append(el("span", "eyebrow", `Selected · ${row.group.slice(0, 2)}`), el("h2", "", treeName(row)));
  const details = el("dl", "detail-grid");
  details.append(
    detail("Tree no.", row.tree_no), detail("Serial no.", row.sl_no),
    detail("Botanical name", row.botanical_name), detail("Action", row.cutting_transplanting),
    detail("Condition", row.condition_of_tree), detail("PDF page", row.source_page),
    detail("Latitude", row.latitude), detail("Longitude", row.longitude),
    detail("Girth", row.girth_m ? `${row.girth_m} m` : ""),
    detail("Height", row.approx_height_m ? `${row.approx_height_m} m` : ""),
    detail("Canopy", row.canopy_diameter_m ? `${row.canopy_diameter_m} m` : ""),
    detail("Location", row.location || row.location_ch),
  );
  ui.selected.append(details);
  const source = el("div", "source-link");
  const link = el("a", "", `Open source CSV · record ${row.csvRecord}`);
  link.href = row.path;
  link.target = "_blank";
  link.rel = "noopener";
  source.append(link, el("span", "", headingLabel(row.heading)));
  ui.selected.append(source);
  if (row.issue) ui.selected.append(el("p", "issue", `Map issue: ${row.issue}`));
  if (navigate) {
    ui.selected.scrollIntoView({ behavior: "smooth", block: "nearest" });
    if (!row.issue) state.map.flyTo([row.lat, row.lon], Math.max(state.map.getZoom(), 17), { duration: 0.5 });
  }
}

function markerColor(rows) {
  const kinds = new Set(rows.map(row => row.actionKey));
  return kinds.size > 1 ? "mixed" : rows[0].actionKey;
}

function markerIcon(rows) {
  const kind = markerColor(rows);
  const count = rows.length;
  return L.divIcon({
    className: "",
    html: `<span class="map-marker ${kind} ${count > 1 ? "cluster" : "single"}">${count > 1 ? count : ""}</span>`,
    iconSize: count > 1 ? [38, 38] : [18, 18],
    iconAnchor: count > 1 ? [19, 19] : [9, 9],
  });
}

function renderMarkers() {
  if (!state.map) return;
  state.markers.clearLayers();
  const cells = new Map();
  const zoom = state.map.getZoom();
  for (const row of state.filtered) {
    if (row.issue) continue;
    const point = state.map.project([row.lat, row.lon], zoom);
    const key = `${Math.floor(point.x / 42)}:${Math.floor(point.y / 42)}`;
    if (!cells.has(key)) cells.set(key, []);
    cells.get(key).push(row);
  }
  for (const rows of cells.values()) {
    const lat = rows.reduce((sum, row) => sum + row.lat, 0) / rows.length;
    const lon = rows.reduce((sum, row) => sum + row.lon, 0) / rows.length;
    const marker = L.marker([lat, lon], { icon: markerIcon(rows), keyboard: true, title: `${rows.length} tree${rows.length === 1 ? "" : "s"}` });
    marker.on("click", () => {
      if (rows.length === 1) {
        selectRow(rows[0], false);
        return;
      }
      const uniquePositions = new Set(rows.map(row => `${row.lat},${row.lon}`));
      if (uniquePositions.size > 1 && state.map.getZoom() < 19) {
        state.map.setView([lat, lon], state.map.getZoom() + 2);
        return;
      }
      const popup = el("div", "cluster-popup");
      popup.append(el("strong", "", `${rows.length} ${uniquePositions.size > 1 ? "nearby trees" : "trees at this location"}`));
      const list = el("div", "popup-list");
      list.append(...rows.slice(0, 30).map(row => rowButton(row, true)));
      popup.append(list);
      if (rows.length > 30) popup.append(el("small", "", `Showing 30 of ${rows.length}. Use the left list for all rows.`));
      marker.bindPopup(popup, { maxWidth: 270 }).openPopup();
    });
    state.markers.addLayer(marker);
  }
}

function fitResults() {
  const locations = state.filtered.filter(row => !row.issue).map(row => [row.lat, row.lon]);
  if (locations.length) state.map.fitBounds(L.latLngBounds(locations).pad(0.09), { maxZoom: 17 });
}

function setupMap() {
  state.map = L.map("map", { preferCanvas: true, zoomControl: false });
  L.control.zoom({ position: "topright" }).addTo(state.map);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
  }).addTo(state.map);
  state.markers = L.layerGroup().addTo(state.map);
  state.map.setView([13.039, 77.587], 14);
  state.map.on("zoomend", renderMarkers);
}

function wireEvents() {
  $("#filters").addEventListener("input", () => { state.visibleLimit = 80; filterRows(); });
  $("#filters").addEventListener("change", () => { state.visibleLimit = 80; filterRows(); });
  $("#fit").addEventListener("click", fitResults);
  $("#reset").addEventListener("click", () => {
    $("#filters").reset();
    state.visibleLimit = 80;
    filterRows();
    fitResults();
  });
  ui.more.addEventListener("click", () => { state.visibleLimit += 80; renderRows(); $("#list-caption").textContent = `${Math.min(state.visibleLimit, state.filtered.length)} shown`; });
}

async function start() {
  if (!window.L) {
    ui.status.textContent = "Map library did not load. Check your internet connection and reload.";
    ui.status.classList.add("error");
    return;
  }
  setupMap();
  wireEvents();
  try {
    await loadData();
    setupFilters();
    filterRows();
    fitResults();
    ui.status.textContent = `${state.headings.length} headings loaded from the source CSVs.`;
  } catch (error) {
    ui.status.textContent = `Could not load survey CSVs: ${error.message}. Open this page through a web server, or check the CSV paths.`;
    ui.status.classList.add("error");
  }
}

start();
