# swift-office-kit

Fill Word templates and write Excel cells **in the files people already have**
— no Word, no Excel, no LibreOffice. A `.docx` and an `.xlsx` are zips of XML;
this edits the XML it must and copies every other part byte for byte, then
reopens what it wrote and checks it before keeping it.

```swift
import OfficeKit

var offer = try WordTemplate(contentsOf: template)
try offer.fields.map(\.name)              // ["customer.name", "items.qty", …]
let report = try offer.fill([
    "customer": .group(["name": .text("Anna Smith")]),
    "items": .list([["desc": .text("Widget"), "qty": .text("2")]]),
])
try offer.write(to: filled)               // reopened and checked first

var budget = try Workbook(contentsOf: book)
try budget.set([("B4", .number(1250)), ("B5", .formula("SUM(B1:B4)")),
                ("C1", .date(year: 2026, month: 10, day: 10))])
try budget.append([[.text("Phone"), .number(30)]])
try budget.write(to: updated)             // every written cell read back first
```

## Word: the split-run trap

A paragraph's text is cut into runs wherever formatting, spell-checking or
revision history changes — and a placeholder is cut with it. A find-and-replace
inside each run misses those. **Measured on 88 real templates** (the
docxtemplater test corpus, used for measurement only and not redistributed):
Word had split **65 of 197 tags (33%)** across runs, LibreOffice 11 of 90 (12%),
WPS 1 of 18.

So a paragraph is read as one string across all its `w:t` nodes, the
placeholder is found in that, and the value goes into the run the placeholder
*starts* in — keeping that run's formatting — while its pieces in later runs
are cut away. Converted to `{{…}}` (keeping Word's own splits), the 43 templates
with plain placeholders held 177 of them, **86 split** (84 of Word's 138);
**all 177 were filled, none were left, and all 119 distinct values were found
in the written files.** python-docx and macOS `textutil` opened all 43 outputs
and Quick Look rendered them. (python-docx missed 9 values that sit in
first-page and even-page headers and 2 in content controls; `textutil` misses
headers — reader blind spots, confirmed in the XML.)

- `{{ name }}` — double braces, spaces allowed; a single brace is prose.
- `{{customer.name}}` reaches into a group.
- A table row whose placeholders start `items.` is repeated once per entry of
  the list `items`; an empty list removes the row.
- Body, every header and footer, footnotes and endnotes; text boxes and
  hyperlinks included.
- A newline in a value becomes a line break inside the same run.
- Missing values are refused, **all named**, before anything changes
  (`allowMissing` leaves them in place); values never used are reported.

## Excel: cells without collateral damage

- Cells and rows are inserted **in order** — Excel calls a file with them out
  of order corrupt — and the stale `spans` hint is dropped from a changed row.
- Text is written inline, so the shared-string table is **never rewritten**
  (checked byte for byte in the tests), nor any sheet not written to.
- A cell keeps its style. A date gets a copy of the cell's own style with an
  ISO `yyyy-mm-dd` format added, so a bold cell stays bold.
- Typed like a cell: `=` formula, `'` forces text (`'00123`), TRUE/FALSE,
  `YYYY-MM-DD` dates, plain numbers (`007` stays text; `1,000` is not guessed).
- **Formulas are not computed here.** The workbook is marked
  `fullCalcOnLoad="1"` so Excel and Numbers recalculate on open, and Excel's
  calculation chain is removed with its relationship and content type — a
  stale one is what makes Excel offer to "repair" a file. A formula reads back
  as its formula; `cached` is the stale saved result.
- Writing over the first cell of a **shared formula** is refused: the cells
  below copy it.

**Measured on 40 real workbooks** (Apache POI's test data, Apache-2.0; 38 made
by Excel): a number, text, a date, a formula and a boolean written to a fresh
column and read back by openpyxl — **40 of 40**, with every sheet and defined
name unchanged. The first run was 39: `47889.xlsx` has an empty
`<styleSheet/>`, so there was no cell format to base a date on. A style sheet
that is empty or missing is now completed in schema order with the font, the
two fills (none, gray125), the border and the default format Excel insists on.

## Checked, not assumed

`write(to:)` reopens the file: the zip opens, `[Content_Types].xml` and every
XML part parse, no placeholder is left but the allowed ones, every value put in
is in the text — or, for a workbook, every cell written reads back as written.
A copy that fails is deleted and `OfficeError.unverified` says why.

## Not done

Recalculating formulas; extending an Excel table (ListObject) when rows are
appended below it; `{{…}}` in spreadsheet text; placeholders inside fields or
comments. LibreOffice was not available to test against here.

## Layout

`Core/` OfficePackage (the zip, parts in order), WordTemplate, Workbook ·
`Support/` ParagraphText (the run merge), Placeholders, ValueLookup,
CellAddress, CellInput, DateSerial (with the 29 February 1900 that never was),
NumberFormats, StyleSheet, PackageCheck · `Models/`, `Errors/`. One dependency:
ZIPFoundation, already in the fleet through CoreXLSX.

## Requirements

macOS 14, Swift 6.

## License

MIT — see [LICENSE](LICENSE).
