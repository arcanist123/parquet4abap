"""Generate the golden Parquet corpus.

Writes, for every case below:
  testdata/golden/<name>.parquet   the file, written by pyarrow or DuckDB
  testdata/golden/<name>.json      what an independent reader (pyarrow) finds in it
and the test-only ABAP class src/zparq2a_cl_golden.clas.abap, which embeds the
files and the facts from the JSON, so the ABAP Unit tests need no file access.

Usage (from the repository root):
  python -m venv tools/.venv
  tools/.venv/Scripts/pip install -r tools/golden/requirements.txt   (Windows)
  tools/.venv/bin/pip install -r tools/golden/requirements.txt       (Linux, macOS)
  tools/.venv/Scripts/python tools/golden/generate.py

The output only depends on the pinned versions in requirements.txt.
"""

import datetime
import decimal
import json
import pathlib
import struct

import duckdb
import pyarrow as pa
import pyarrow.parquet as pq

ROOT = pathlib.Path(__file__).resolve().parents[2]
GOLDEN = ROOT / "testdata" / "golden"
SRC = ROOT / "src"
CLASS = "zparq2a_cl_golden"


def flat_table():
    return pa.table({
        "id": pa.array([1, 2, 3, 4], pa.int32()),
        "big": pa.array([-1, 0, 2**40, -(2**63)], pa.int64()),
        "ratio": pa.array([0.5, None, -1.25, 1e300], pa.float64()),
        "small": pa.array([1.5, 2.0, None, -0.0], pa.float32()),
        "flag": pa.array([True, False, None, True], pa.bool_()),
        "name": pa.array(["alpha", "beta", None, "ä€"], pa.string()),
        "raw": pa.array([b"\x00\x01", b"", None, b"\xff"], pa.binary()),
        "day": pa.array([datetime.date(2024, 2, 29), None,
                         datetime.date(1970, 1, 1), datetime.date(1, 1, 1)],
                        pa.date32()),
        "ts": pa.array([0, 1_700_000_000_000_000, None, -1],
                       pa.timestamp("us", tz="UTC")),
        "amount": pa.array([decimal.Decimal("12.34"), decimal.Decimal("-0.01"),
                            None, decimal.Decimal("9999999.99")],
                           pa.decimal128(9, 2)),
    })


def logical_table():
    return pa.table({
        "i8": pa.array([-128, 127], pa.int8()),
        "u16": pa.array([0, 65535], pa.uint16()),
        "u64": pa.array([0, 2**64 - 1], pa.uint64()),
        "t_ms": pa.array([0, 86_399_999], pa.time32("ms")),
        "t_ns": pa.array([0, 86_399_999_999_999], pa.time64("ns")),
        "ts_ns": pa.array([0, 1], pa.timestamp("ns")),
        "ts_ms_tz": pa.array([0, 1], pa.timestamp("ms", tz="Europe/Berlin")),
        "fixed": pa.array([b"abcd", b"wxyz"], pa.binary(4)),
        "dec38": pa.array([decimal.Decimal("1.5"), decimal.Decimal("-2.25")],
                          pa.decimal128(38, 10)),
        "half": pa.array([1.0, -2.0], pa.float16()),
        "uuid": pa.array([b"\x01" * 16, b"\x02" * 16], pa.uuid()),
        "empty": pa.array([None, None], pa.null()),
    })


def nested_table():
    return pa.table({
        "tags": pa.array([["a", "b"], [], None], pa.list_(pa.string())),
        "point": pa.array([{"x": 1, "y": 2.0}, None, {"x": 3, "y": None}],
                          pa.struct([("x", pa.int32()), ("y", pa.float64())])),
        "attrs": pa.array([[("k", 1)], None, []], pa.map_(pa.string(), pa.int64())),
    })


def write_pyarrow(name, table, **options):
    path = GOLDEN / f"{name}.parquet"
    pq.write_table(table, path, **options)
    return path


def write_duckdb(name, sql, **options):
    path = GOLDEN / f"{name}.parquet"
    settings = ", ".join(f"{k} {v}" for k, v in options.items())
    con = duckdb.connect()
    con.execute(f"COPY ({sql}) TO '{path.as_posix()}' (FORMAT parquet, {settings})")
    con.close()
    return path


DUCKDB_SQL = """
SELECT i::INTEGER AS id,
       (i * 1000000007)::BIGINT AS big,
       CASE WHEN i % 3 = 0 THEN NULL ELSE i / 7 END::DOUBLE AS ratio,
       'row ' || (i % 4) AS label,
       (i % 2 = 0) AS even,
       DATE '2024-01-01' + i::INTEGER AS day,
       TIMESTAMP '2024-01-01 00:00:00' + INTERVAL (i) SECOND AS ts,
       (i / 100)::DECIMAL(18, 3) AS amount,
       [i, i + 1] AS pair
FROM range(10) t(i)
"""


def cases():
    flat = flat_table()
    yield "pa_plain_none", "pyarrow", write_pyarrow(
        "pa_plain_none", flat, use_dictionary=False, compression="none")
    yield "pa_dict_snappy", "pyarrow", write_pyarrow(
        "pa_dict_snappy", flat)
    yield "pa_v2_gzip_groups", "pyarrow", write_pyarrow(
        "pa_v2_gzip_groups", flat, compression="gzip", data_page_version="2.0",
        row_group_size=2, store_schema=False,
        sorting_columns=[pq.SortingColumn(0), pq.SortingColumn(1, descending=True,
                                                                nulls_first=True)])
    yield "pa_plain_gzip", "pyarrow", write_pyarrow(
        "pa_plain_gzip", flat, use_dictionary=False, compression="gzip")
    # one value per page: write_batch_size=1 lets every value end a page
    yield "pa_v2_plain_pages", "pyarrow", write_pyarrow(
        "pa_v2_plain_pages", flat, use_dictionary=False, compression="gzip",
        data_page_version="2.0", row_group_size=3, data_page_size=1,
        write_batch_size=1)
    yield "pa_index_crc_bloom", "pyarrow", write_pyarrow(
        "pa_index_crc_bloom", flat, compression="none", write_page_index=True,
        write_page_checksum=True,
        bloom_filter_options={"id": True, "name": True})
    yield "pa_logical", "pyarrow", write_pyarrow(
        "pa_logical", logical_table(), compression="none",
        coerce_timestamps=None, allow_truncated_timestamps=False)
    yield "pa_logical_plain", "pyarrow", write_pyarrow(
        "pa_logical_plain", logical_table(), compression="none", use_dictionary=False,
        coerce_timestamps=None, allow_truncated_timestamps=False)
    yield "pa_nested", "pyarrow", write_pyarrow(
        "pa_nested", nested_table(), compression="none")
    yield "duckdb_snappy", "duckdb", write_duckdb(
        "duckdb_snappy", DUCKDB_SQL, COMPRESSION="snappy")
    yield "duckdb_v2_none", "duckdb", write_duckdb(
        "duckdb_v2_none", DUCKDB_SQL, COMPRESSION="uncompressed",
        PARQUET_VERSION="V2")


def describe(path, writer):
    """What pyarrow, as an independent reader, finds in the file."""
    data = path.read_bytes()
    footer_length = struct.unpack("<i", data[-8:-4])[0]
    meta = pq.ParquetFile(path).metadata
    schema = meta.schema
    columns = []
    for rg in range(meta.num_row_groups):
        group = meta.row_group(rg)
        for c in range(group.num_columns):
            col = group.column(c)
            columns.append({
                "row_group": rg,
                "column": c,
                "path": col.path_in_schema,
                "physical_type": col.physical_type,
                "codec": col.compression,
                "num_values": col.num_values,
                "data_page_offset": col.data_page_offset,
                "dictionary_page_offset": col.dictionary_page_offset,
                "total_compressed_size": col.total_compressed_size,
                "total_uncompressed_size": col.total_uncompressed_size,
                "has_statistics": col.is_stats_set,
            })
    return {
        "writer": writer,
        "size": len(data),
        "footer_length": footer_length,
        "created_by": meta.created_by,
        "format_version": meta.format_version,
        "num_rows": meta.num_rows,
        "num_row_groups": meta.num_row_groups,
        "row_group_rows": [meta.row_group(i).num_rows for i in range(meta.num_row_groups)],
        "leaf_columns": [schema.column(i).path for i in range(len(schema))],
        "key_value_keys": sorted(k.decode() for k in (meta.metadata or {})),
        "columns": columns,
    }


# ---------------------------------------------------------------- ABAP output

PHYSICAL = {"BOOLEAN": 0, "INT32": 1, "INT64": 2, "INT96": 3, "FLOAT": 4,
            "DOUBLE": 5, "BYTE_ARRAY": 6, "FIXED_LEN_BYTE_ARRAY": 7}
CODEC = {"UNCOMPRESSED": 0, "SNAPPY": 1, "GZIP": 2, "LZO": 3, "BROTLI": 4,
         "LZ4": 5, "ZSTD": 6, "LZ4_RAW": 7}


def abap_text(value):
    return "`" + value.replace("`", "``") + "`"


def hex_lines(data, width=96):
    text = data.hex().upper()
    return [text[i:i + width] for i in range(0, len(text), width)] or [""]


def abap_class(entries):
    out = []
    w = out.append
    w('"! <p class="shorttext synchronized">Parquet: golden test files</p>')
    w('"! Generated by tools/golden/generate.py. Do not edit.')
    w('"! The files in testdata/golden, with the facts an independent reader')
    w('"! (pyarrow) finds in them.')
    w(f"CLASS {CLASS} DEFINITION")
    w("  PUBLIC")
    w("  FINAL")
    w("  CREATE PRIVATE")
    w("  FOR TESTING.")
    w("")
    w("  PUBLIC SECTION.")
    w("    TYPES:")
    w("      BEGIN OF ty_column,")
    w("        row_group              TYPE i,")
    w("        \"! Index in the row group, from 0")
    w("        column                 TYPE i,")
    w("        path                   TYPE string,")
    w("        physical_type          TYPE i,")
    w("        codec                  TYPE i,")
    w("        num_values             TYPE int8,")
    w("        data_page_offset       TYPE int8,")
    w("        dictionary_page_offset TYPE int8,")
    w("        total_compressed_size  TYPE int8,")
    w("        has_statistics         TYPE abap_bool,")
    w("      END OF ty_column,")
    w("      ty_columns TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY,")
    w("      BEGIN OF ty_file,")
    w("        name           TYPE string,")
    w("        data           TYPE xstring,")
    w("        footer_length  TYPE i,")
    w("        created_by     TYPE string,")
    w("        num_rows       TYPE int8,")
    w("        num_row_groups TYPE i,")
    w("        leaf_columns   TYPE string_table,")
    w("        key_value_keys TYPE string_table,")
    w("        columns        TYPE ty_columns,")
    w("      END OF ty_file,")
    w("      ty_files TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.")
    w("")
    w("    CLASS-METHODS files")
    w("      RETURNING")
    w("        VALUE(result) TYPE ty_files.")
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
    for name, _ in entries:
        w(f"    CLASS-METHODS {name}")
        w("      RETURNING")
        w("        VALUE(result) TYPE ty_file.")
        w("")
    w("ENDCLASS.")
    w("")
    w("")
    w(f"CLASS {CLASS} IMPLEMENTATION.")
    w("")
    w("  METHOD files.")
    for name, _ in entries:
        w(f"    APPEND {name}( ) TO result.")
    w("  ENDMETHOD.")
    w("")
    w("  METHOD from_hex.")
    w("    DATA hex TYPE string.")
    w("")
    w("    CONCATENATE LINES OF lines INTO hex.")
    w("    result = hex.")
    w("  ENDMETHOD.")
    for name, (path, info) in entries:
        w("")
        w(f"  METHOD {name}.")
        w("    DATA lines TYPE string_table.")
        w("")
        w(f"    result-name = {abap_text(name)}.")
        w(f"    result-footer_length = {info['footer_length']}.")
        w(f"    result-created_by = {abap_text(info['created_by'])}.")
        w(f"    result-num_rows = {info['num_rows']}.")
        w(f"    result-num_row_groups = {info['num_row_groups']}.")
        w("    result-leaf_columns = VALUE #(")
        for leaf in info["leaf_columns"]:
            w(f"      ( {abap_text(leaf)} )")
        w("    ).")
        if info["key_value_keys"]:
            w("    result-key_value_keys = VALUE #(")
            for key in info["key_value_keys"]:
                w(f"      ( {abap_text(key)} )")
            w("    ).")
        w("    result-columns = VALUE #(")
        for col in info["columns"]:
            w("      ( row_group              = " + str(col['row_group']))
            w(f"        column                 = {col['column']}")
            w(f"        path                   = {abap_text(col['path'])}")
            w(f"        physical_type          = {PHYSICAL[col['physical_type']]}")
            w(f"        codec                  = {CODEC[col['codec']]}")
            w(f"        num_values             = {col['num_values']}")
            w(f"        data_page_offset       = {col['data_page_offset']}")
            w(f"        dictionary_page_offset = {col['dictionary_page_offset'] or 0}")
            w(f"        total_compressed_size  = {col['total_compressed_size']}")
            w(f"        has_statistics         = {'abap_true' if col['has_statistics'] else 'abap_false'} )")
        w("    ).")
        w("    lines = VALUE #(")
        for line in hex_lines(path.read_bytes()):
            w(f"      ( `{line}` )")
        w("    ).")
        w("    result-data = from_hex( lines ).")
        w("  ENDMETHOD.")
    w("")
    w("ENDCLASS.")
    return "\n".join(out) + "\n"


ABAP_XML = """<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_CLAS" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOCLASS>
    <CLSNAME>ZPARQ2A_CL_GOLDEN</CLSNAME>
    <LANGU>E</LANGU>
    <DESCRIPT>Parquet: golden test files</DESCRIPT>
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


def main():
    GOLDEN.mkdir(parents=True, exist_ok=True)
    entries = []
    for name, writer, path in cases():
        info = describe(path, writer)
        info["generator"] = {"pyarrow": pa.__version__, "duckdb": duckdb.__version__}
        (GOLDEN / f"{name}.json").write_text(json.dumps(info, indent=2) + "\n",
                                             encoding="utf-8", newline="\n")
        entries.append((name, (path, info)))
        print(f"{name:22} {info['size']:6} bytes, footer {info['footer_length']} bytes")
    (SRC / f"{CLASS}.clas.abap").write_text(abap_class(entries), encoding="utf-8",
                                            newline="\n")
    (SRC / f"{CLASS}.clas.xml").write_text(ABAP_XML, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
