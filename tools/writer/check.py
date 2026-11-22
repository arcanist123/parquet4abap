"""Check the sample files of the ABAP writer with independent readers.

ZPARQ2A_CL_SAMPLES writes fixed datasets with ZPARQ2A_CL_WRITER. This script
describes the same datasets on its own, has pyarrow and DuckDB read the files,
and compares the schema and every value.

Usage (from the repository root):
  tools/.venv/Scripts/python tools/writer/check.py DIR            (Windows)
  tools/.venv/bin/python tools/writer/check.py DIR                (Linux, macOS)
  ... check.py DIR --toolchain abaplint-transpiler --update

DIR holds <sample>.parquet files, for example results/samples written by
tools/write-samples.mjs. With --toolchain, samples listed for that toolchain in
tools/known-gaps.json (as SAMPLES/<name>) fail for a known reason: they are
reported as KNOWN and do not fail the run, and as FIXED once they pass.

With --update, the uncompressed samples (names that end in _none) that pass are
copied to testdata/written, and src/zparq2a_cl_written.clas.abap is generated
from all files there, so the ABAP Unit tests can check that every toolchain
writes the same bytes. Files are added or replaced, never removed.

Exit code: 0 when no sample failed unexpectedly, 1 otherwise.
"""

import datetime
import decimal
import json
import pathlib
import shutil
import sys

import duckdb
import pyarrow as pa
import pyarrow.parquet as pq

ROOT = pathlib.Path(__file__).resolve().parents[2]
WRITTEN = ROOT / "testdata" / "written"
SRC = ROOT / "src"
CLASS = "zparq2a_cl_written"
D = decimal.Decimal

# ------------------------------------------------------------ the datasets

FLAT_TYPES = [
    # column, pyarrow type, DuckDB type
    ("id", pa.int32(), "INTEGER"),
    ("tiny", pa.uint8(), "UTINYINT"),
    ("short", pa.int16(), "SMALLINT"),
    ("big", pa.int64(), "BIGINT"),
    ("ratio", pa.float64(), "DOUBLE"),
    ("price", pa.decimal128(7, 3), "DECIMAL(7,3)"),
    ("amount", pa.decimal128(15, 2), "DECIMAL(15,2)"),
    ("total", pa.decimal128(31, 4), "DECIMAL(31,4)"),
    ("flag", pa.bool_(), "BOOLEAN"),
    ("code", pa.string(), "VARCHAR"),
    ("digits", pa.string(), "VARCHAR"),
    ("text", pa.string(), "VARCHAR"),
    ("raw", pa.binary(), "BLOB"),
    ("hash", pa.binary(4), "BLOB"),
    ("day", pa.date32(), "DATE"),
    ("time", pa.time32("ms"), "TIME"),
]

# negating a Decimal would round it to the default context of 28 digits
MAX31 = D("999999999999999999999999999.9999")
MIN31 = D("-999999999999999999999999999.9999")

FLAT_ROWS = [
    {"id": 1, "tiny": 0, "short": -32768, "big": -2**63, "ratio": 0.5,
     "price": D("1.5"), "amount": D("-0.01"), "total": MAX31, "flag": True,
     "code": "ABC", "digits": "000042", "text": "alpha", "raw": b"\x00\x01",
     "hash": bytes.fromhex("DEADBEEF"), "day": datetime.date(2024, 2, 29),
     "time": datetime.time(23, 59, 59)},
    {"id": 2, "tiny": 255, "short": 32767, "big": 2**63 - 1, "ratio": -1.25,
     "price": D("-9999.999"), "amount": D("9999999999999.99"), "total": MIN31,
     "flag": False, "code": "  lead", "digits": "999999", "text": "", "raw": b"",
     "hash": bytes(4), "day": datetime.date(1970, 1, 1),
     "time": datetime.time(0, 0, 0)},
    {"id": -2**31, "tiny": 7, "short": -1, "big": -1, "ratio": 1e300,
     "price": D(0), "amount": D(0), "total": D("0.0001"), "flag": True,
     "code": "äöü€", "digits": "000000", "text": "Grüße, 世界", "raw": b"\xff",
     "hash": bytes.fromhex("01020304"), "day": datetime.date(1900, 1, 1),
     "time": datetime.time(12, 0, 0)},
    {"id": 2**31 - 1, "tiny": 128, "short": 0, "big": 2**40, "ratio": 0.0,
     "price": D("-0.001"), "amount": D("-9999999999999.99"), "total": D("-0.0001"),
     "flag": False, "code": "full width", "digits": "123456",
     "text": 'tab\tand "quotes"', "raw": bytes.fromhex("00FF00FF00FF"),
     "hash": b"\xff" * 4, "day": datetime.date(9999, 12, 31),
     "time": datetime.time(0, 0, 1)},
]

OPTIONAL_TYPES = [
    ("id", pa.int32(), "INTEGER"),
    ("count", pa.int32(), "INTEGER"),
    ("name", pa.string(), "VARCHAR"),
    ("score", pa.float64(), "DOUBLE"),
    ("day", pa.date32(), "DATE"),
    ("flag", pa.bool_(), "BOOLEAN"),
    ("amount", pa.decimal128(11, 2), "DECIMAL(11,2)"),
]


def optional_rows():
    rows = []
    for i in range(1, 21):
        rows.append({
            "id": i,
            "count": i * 100 if i % 3 else None,
            "name": f"name {i}" if i < 5 or i > 16 else None,
            "score": -0.75 if i == 20 else None,
            "day": datetime.date(2024, 1, 1) + datetime.timedelta(days=i),
            "flag": i % 2 == 0,
            "amount": i * D("1.25") if i % 2 else None,
        })
    return rows


# name: (columns, rows, required columns)
SAMPLES = {
    "flat_none": (FLAT_TYPES, FLAT_ROWS, True),
    "optional_none": (OPTIONAL_TYPES, optional_rows(), False),
    "optional_gzip": (OPTIONAL_TYPES, optional_rows(), False),
    "empty_none": (FLAT_TYPES, [], True),
}

CODECS = {"flat_none": "UNCOMPRESSED", "optional_none": "UNCOMPRESSED",
          "empty_none": "UNCOMPRESSED", "optional_gzip": "GZIP"}


# ------------------------------------------------------------ the checks

def check_pyarrow(path, columns, rows, required):
    problems = []
    file = pq.ParquetFile(path)
    schema = file.schema_arrow
    names = [name for name, _, _ in columns]
    if schema.names != names:
        return [f"pyarrow: columns {schema.names}, expected {names}"]
    for name, arrow_type, _ in columns:
        field = schema.field(name)
        if field.type != arrow_type:
            problems.append(f"pyarrow: {name} is {field.type}, expected {arrow_type}")
        nullable = not required and name != "id"
        if field.nullable != nullable:
            problems.append(f"pyarrow: {name} nullable={field.nullable}, expected {nullable}")
    actual = file.read().to_pylist()
    if len(actual) != len(rows):
        problems.append(f"pyarrow: {len(actual)} rows, expected {len(rows)}")
    for index, (got, want) in enumerate(zip(actual, rows)):
        for name in names:
            if got[name] != want[name] or type(got[name]) is not type(want[name]):
                problems.append(f"pyarrow: row {index + 1} {name} = {got[name]!r}, expected {want[name]!r}")
    return problems


def check_codecs(path, codec):
    meta = pq.ParquetFile(path).metadata
    problems = []
    for group in range(meta.num_row_groups):
        for column in range(meta.num_columns):
            chunk = meta.row_group(group).column(column)
            expected = "UNCOMPRESSED" if chunk.path_in_schema == "id" else codec
            if chunk.compression != expected:
                problems.append(f"metadata: {chunk.path_in_schema} is {chunk.compression}, expected {expected}")
    return problems


def check_duckdb(path, columns, rows):
    problems = []
    con = duckdb.connect()
    try:
        relation = con.read_parquet(str(path))
        types = [str(t) for t in relation.types]
        expected_types = [duck for _, _, duck in columns]
        if types != expected_types:
            problems.append(f"DuckDB: types {types}, expected {expected_types}")
        actual = relation.fetchall()
    finally:
        con.close()
    names = [name for name, _, _ in columns]
    expected = [tuple(row[name] for name in names) for row in rows]
    if len(actual) != len(expected):
        problems.append(f"DuckDB: {len(actual)} rows, expected {len(expected)}")
    for index, (got, want) in enumerate(zip(actual, expected)):
        for name, g, w in zip(names, got, want):
            if g != w:
                problems.append(f"DuckDB: row {index + 1} {name} = {g!r}, expected {w!r}")
    return problems


def known_gaps(toolchain):
    if toolchain is None:
        return {}
    gaps = json.loads((ROOT / "tools" / "known-gaps.json").read_text(encoding="utf-8"))
    return {key.split("/", 1)[1]: gap for key, gap in gaps.get(toolchain, {}).items()
            if key.startswith("SAMPLES/")}


def check(directory, gaps):
    """Returns the samples that pass and those that fail unexpectedly."""
    passed, failed = [], []
    for name, (columns, rows, required) in SAMPLES.items():
        path = directory / f"{name}.parquet"
        gap = gaps.get(name)
        if not path.exists():
            problems = ["file missing"]
        else:
            problems = (check_pyarrow(path, columns, rows, required)
                        + check_codecs(path, CODECS[name])
                        + check_duckdb(path, columns, rows))
        if problems:
            status = "KNOWN" if gap else "FAILED"
        else:
            status = "FIXED" if gap else "OK"
        size = f"  ({path.stat().st_size} bytes)" if path.exists() else ""
        print(f"{name:14} {status}{size}{f'  {gap}' if gap else ''}")
        for problem in problems:
            print(f"  {problem}")
        if not problems:
            passed.append(name)
        elif not gap:
            failed.append(name)
    return passed, failed


# ------------------------------------------------------------ ABAP output

def hex_lines(data, width=96):
    text = data.hex().upper()
    return [text[i:i + width] for i in range(0, len(text), width)] or [""]


def abap_class(files):
    out = []
    w = out.append
    w('"! <p class="shorttext synchronized">Parquet: checked writer output</p>')
    w('"! Generated by tools/writer/check.py --update. Do not edit.')
    w('"! The files in testdata/written: uncompressed samples of ZPARQ2A_CL_SAMPLES')
    w('"! that pyarrow and DuckDB read with the expected values.')
    w(f"CLASS {CLASS} DEFINITION")
    w("  PUBLIC")
    w("  FINAL")
    w("  CREATE PRIVATE")
    w("  FOR TESTING.")
    w("")
    w("  PUBLIC SECTION.")
    w("    CLASS-METHODS files")
    w("      RETURNING")
    w("        VALUE(result) TYPE zparq2a_cl_samples=>ty_samples.")
    w("")
    w("  PROTECTED SECTION.")
    w("")
    w("  PRIVATE SECTION.")
    w("    CLASS-METHODS from_hex")
    w("      IMPORTING")
    w("        lines         TYPE string_table")
    w("      RETURNING")
    w("        VALUE(result) TYPE xstring.")
    w("")
    for name, _ in files:
        w(f"    CLASS-METHODS {name}")
        w("      RETURNING")
        w("        VALUE(result) TYPE xstring.")
        w("")
    w("ENDCLASS.")
    w("")
    w("")
    w(f"CLASS {CLASS} IMPLEMENTATION.")
    w("")
    w("  METHOD files.")
    for name, _ in files:
        w(f"    APPEND VALUE #( name = `{name}` data = {name}( ) ) TO result.")
    w("  ENDMETHOD.")
    w("")
    w("  METHOD from_hex.")
    w("    DATA hex TYPE string.")
    w("")
    w("    CONCATENATE LINES OF lines INTO hex.")
    w("    result = hex.")
    w("  ENDMETHOD.")
    for name, data in files:
        w("")
        w(f"  METHOD {name}.")
        w("    DATA lines TYPE string_table.")
        w("")
        w("    lines = VALUE #(")
        for line in hex_lines(data):
            w(f"      ( `{line}` )")
        w("    ).")
        w("    result = from_hex( lines ).")
        w("  ENDMETHOD.")
    w("")
    w("ENDCLASS.")
    return "\n".join(out) + "\n"


ABAP_XML = """<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_CLAS" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOCLASS>
    <CLSNAME>ZPARQ2A_CL_WRITTEN</CLSNAME>
    <LANGU>E</LANGU>
    <DESCRIPT>Parquet: checked writer output</DESCRIPT>
    <CATEGORY>05</CATEGORY>
    <STATE>1</STATE>
    <CLSCCINCL>X</CLSCCINCL>
    <FIXPT>X</FIXPT>
    <UNICODE>X</UNICODE>
   </VSEOCLASS>
  </asx:values>
 </asx:abap>
</abapGit>
"""


def update(directory, passed):
    # files that passed earlier stay, also when this toolchain fails them for a known reason
    WRITTEN.mkdir(parents=True, exist_ok=True)
    for name in passed:
        if name.endswith("_none"):
            shutil.copyfile(directory / f"{name}.parquet", WRITTEN / f"{name}.parquet")
    files = [(name, (WRITTEN / f"{name}.parquet").read_bytes())
             for name in SAMPLES if (WRITTEN / f"{name}.parquet").exists()]
    (SRC / f"{CLASS}.clas.abap").write_text(abap_class(files), encoding="utf-8", newline="\n")
    (SRC / f"{CLASS}.clas.xml").write_text(ABAP_XML, encoding="utf-8", newline="\n")
    print(f"updated testdata/written and src/{CLASS}.clas.abap")


def main(argv):
    toolchain = None
    if "--toolchain" in argv:
        index = argv.index("--toolchain")
        if index + 1 >= len(argv):
            print(__doc__)
            return 2
        toolchain = argv[index + 1]
        argv = argv[:index] + argv[index + 2:]
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1 or set(argv) - set(args) - {"--update"}:
        print(__doc__)
        return 2
    directory = pathlib.Path(args[0])
    print(f"pyarrow {pa.__version__}, duckdb {duckdb.__version__}")
    passed, failed = check(directory, known_gaps(toolchain))
    if failed:
        print(f"{len(failed)} of {len(SAMPLES)} samples failed")
        return 1
    if "--update" in argv:
        update(directory, passed)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
