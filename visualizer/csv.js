// RFC 4180-style quoted fields, including doubled quotes and embedded newlines.
export function parseCsv(text) {
  const source = text.replace(/^\uFEFF/, "");
  const records = [];
  let record = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i];
    if (quoted) {
      if (ch === '"' && source[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        field += ch;
      }
    } else if (ch === '"' && field === "") {
      quoted = true;
    } else if (ch === ",") {
      record.push(field);
      field = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && source[i + 1] === "\n") i += 1;
      record.push(field);
      if (record.some(value => value !== "")) records.push(record);
      record = [];
      field = "";
    } else {
      field += ch;
    }
  }
  if (quoted) throw new Error("CSV has an unclosed quoted field");
  record.push(field);
  if (record.some(value => value !== "")) records.push(record);
  if (!records.length) return [];
  const [headers, ...rows] = records;
  return rows.map((values, index) => {
    if (values.length !== headers.length) {
      throw new Error(`CSV record ${index + 2} has ${values.length} fields; expected ${headers.length}`);
    }
    return Object.fromEntries(headers.map((header, column) => [header, values[column]]));
  });
}
