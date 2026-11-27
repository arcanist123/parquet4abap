# parquet4abap

An implementation of the [Apache Parquet](https://parquet.apache.org/) file format in native ABAP.

The goal of **parquet4abap** is to read and write Parquet files directly in ABAP, using no external tools, middleware or kernel extensions.

## Goals

- **Read** Parquet files into ABAP internal tables
- **Write** ABAP internal tables to Parquet files
- Pure ABAP, installable with [abapGit](https://abapgit.org/)
- Map Parquet's physical and logical types to ABAP types

## Planned scope

| Area | Status |
|------|--------|
| File structure (magic bytes, footer, row groups, column chunks, pages) | Done |
| Thrift Compact Protocol (file metadata, page headers) | Done |
| Encodings: PLAIN, RLE / bit-packing hybrid (definition levels) | Done |
| Encodings: dictionary | Planned |
| Compression: uncompressed, GZIP | Done |
| Compression: Snappy, ZSTD | Under consideration |
| Flat schemas, optional columns | Done |
| Data pages v2, several row groups and pages per column | Reading done, writing planned |
| Nested schemas (repetition levels) | Under consideration |

## Type mapping

The writer maps each component of the table's line type to a column, named like the
component in lower case:

| ABAP type | Parquet physical type | Logical type |
|-----------|-----------------------|--------------|
| `i` | INT32 | |
| `int8` | INT64 | |
| `b` (`int1`) | INT32 | INTEGER(8, unsigned) |
| `s` (`int2`) | INT32 | INTEGER(16, signed) |
| `f` | DOUBLE | |
| `p` with up to 9 / 18 / 31 digits | INT32 / INT64 / FIXED_LEN_BYTE_ARRAY | DECIMAL(2 × length − 1, decimals) |
| `abap_bool` | BOOLEAN | |
| `c`, `n`, `string` | BYTE_ARRAY, UTF-8 | STRING |
| `x` | FIXED_LEN_BYTE_ARRAY | |
| `xstring` | BYTE_ARRAY | |
| `d` | INT32, days since 1970-01-01 | DATE |
| `t` | INT32, milliseconds since midnight | TIME(MILLIS), not adjusted to UTC |

A component typed as a data reference to one of these types (`REF TO i`, `REF TO string`, ...) is an
optional column: an unbound reference is written as null. All other columns are required. As
ABAP assigns them, `c` values lose their trailing blanks, and `n` values keep their leading zeros.

Dates count days in the proleptic Gregorian calendar, as Parquet readers such as pyarrow do, also
before 1582-10-15, where ABAP date arithmetic is expected to use the Julian calendar. The initial
date `00000000` is not a valid date and raises an error.

## Writing a file

```abap
TYPES:
  BEGIN OF ty_row,
    id    TYPE i,
    name  TYPE string,
    score TYPE REF TO f,     " optional: unbound means null
  END OF ty_row.
DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

rows = VALUE #( ( id = 1 name = `alpha` score = NEW #( '0.5' ) )
                ( id = 2 name = `beta` ) ).

DATA(writer) = NEW zparq2a_cl_writer( NEW zparq2a_cl_comp_gzip( ) ).
writer->set_column_compressor( column = `ID` compressor = NEW zparq2a_cl_comp_none( ) ).
DATA(file) = writer->write( rows ).    " xstring with the Parquet file
```

The file has one row group with one data page per column (data page v1, PLAIN values). Without
a compressor the writer stores pages uncompressed. GZIP uses `CL_ABAP_GZIP`.

## Reading a file

```abap
DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = rows ).
```

The line type says which columns to read: each component is filled from the column with the same
name, ignoring case, and columns it does not name are skipped. A component typed as a data
reference reads an optional column, and a null leaves the reference unbound; a null in any other
component is an error. Any table kind works; a duplicate key is an error.

Values are converted to the component's type as far as no information is lost:

| ABAP type | Parquet columns it reads |
|-----------|--------------------------|
| `i`, `int8`, `b`, `s` | INT32, INT64, also unsigned and other logical types such as TIMESTAMP (the stored number); the value must fit |
| `f` | INT32, INT64, FLOAT, DOUBLE |
| `p` | DECIMAL in any physical type, INT32, INT64; rounded to the component's decimals |
| `abap_bool` | BOOLEAN |
| `c`, `n`, `string` | UTF-8 text (STRING, ENUM, JSON); the text must fit |
| `x` | binary values of exactly its length |
| `xstring` | BYTE_ARRAY, FIXED_LEN_BYTE_ARRAY |
| `d` | DATE |
| `t` | TIME in milliseconds, microseconds or nanoseconds, whole seconds only |

The reader takes data pages v1 and v2, several row groups and several pages per column. Values must
be PLAIN (or RLE for booleans, as pyarrow writes them in data pages v2); dictionary encoding is
not supported yet, and nor are nested schemas. Pages may be uncompressed or GZIP;
`set_compressor( )` adds a codec.

## Installation

Install the repository with [abapGit](https://abapgit.org/).

## Running the tests

The ABAP Unit tests in `src/` run outside an ABAP system on these toolchains:

| Command | Toolchain | Needs |
|---------|-----------|-------|
| `npm test` | abaplint, then the abaplint transpiler | Node, Git |
| `npm run osg` | open-steamgate, Go target | Node, Go, Git |

`npm run lint` (part of `npm test`) clones
[abaplint](https://github.com/abaplint/abaplint) into `tools/abaplint` at the commit
pinned in `tools/toolchains.lock.json` (the branch `parquet4abap` of the fork
[arcanist123/abaplint](https://github.com/arcanist123/abaplint/tree/parquet4abap)), builds the CLI
and lints `src/` with it, so fixes we need apply before they are released on npm.
`npm run lint:local -- <dir> [--build]` uses another checkout. `npm run unit` clones the
[abaplint transpiler](https://github.com/abaplint/transpiler) into `tools/transpiler` at the commit
pinned in `tools/toolchains.lock.json`, builds it, and writes its result to `results/`. While fixes
we need are still open upstream, the lock points at the branch `parquet4abap` of the fork
[arcanist123/transpiler](https://github.com/arcanist123/transpiler/tree/parquet4abap): the latest
upstream main with those pull requests merged, listed under `unmergedPullRequests`. Once they are
merged upstream, the lock goes back to an upstream commit. To try a
fork or a branch of the transpiler instead, point it at that checkout:
`npm run unit:local -- <dir>` uses the checkout as it is, and adding `--build` compiles it first.
Tests listed in `tools/known-gaps.json` fail on a toolchain for a known reason, each with its
upstream issue. They are reported as `KNOWN` and don't fail the run, and as `FIXED` once they
pass. The file has one section per toolchain: `abaplint-transpiler` and `open-steamgate-go`.

`npm run osg` clones open-steamgate into `tools/open-steamgate` at the commit pinned in
`tools/toolchains.lock.json`, sets it up, compiles the tests to Go and writes the result to
`results/osg-go-unit.json`. As for the transpiler, while fixes we need are open upstream the lock
points at the branch `parquet4abap` of the fork
[arcanist123/open-steamgate](https://github.com/arcanist123/open-steamgate/tree/parquet4abap), which
merges those pull requests (`unmergedPullRequests`) into upstream main. It works on Linux, macOS and
native Windows. On Windows the runner adds the workarounds in `tools/osg-win-paths.mjs` and
`tools/osg-windows.patch`.

## Golden files

`testdata/golden/` holds small Parquet files written by pyarrow and DuckDB, each with a JSON file that
says what pyarrow reads from it. The reader's unit tests read the PLAIN-encoded ones into internal
tables and compare every value. `tools/golden/generate.py` writes them, and also writes
`src/zparq2a_cl_golden.clas.abap`, a class for tests only that embeds the files, so the ABAP Unit
tests need no file access. To regenerate them with the versions pinned in
`tools/golden/requirements.txt`:

```sh
python -m venv tools/.venv
tools/.venv/Scripts/pip install -r tools/golden/requirements.txt   # Linux, macOS: tools/.venv/bin/pip
tools/.venv/Scripts/python tools/golden/generate.py
```

## Checking the writer

`ZPARQ2A_CL_SAMPLES` writes fixed datasets: every supported type with edge values, optional
columns with nulls, an empty table, and a GZIP file. `tools/write-samples.mjs` writes them to
`results/samples/` with the code the abaplint transpiler built, and `tools/writer/check.py`
has pyarrow and DuckDB read them and compares the schema and every value with its own
description of the datasets:

```sh
npm run unit
npm run samples
tools/.venv/Scripts/python tools/writer/check.py results/samples --toolchain abaplint-transpiler
```

Samples listed in `tools/known-gaps.json` as `SAMPLES/<name>` fail for a known reason and are
reported as `KNOWN`. With `--update`, the uncompressed samples that pass go to
`testdata/written/` and into `src/zparq2a_cl_written.clas.abap`. A unit test checks that the
writer gives exactly these bytes, so every toolchain is held to the files that pyarrow and
DuckDB read correctly.

## Benchmark

`ZPARQ2A_CL_BENCHMARK` generates a table from a seed, writes it, reads it back and times both
steps. On an ABAP system, the report `ZPARQ2A_BENCHMARK` runs it and prints one line per run.
`npm run bench` runs it on the toolchains: on the abaplint transpiler with the code `npm run unit`
built, and on open-steamgate's Go target as a native executable built from the report. It keeps
each toolchain's file in `results/bench/`, checks it with pyarrow (`tools/bench/check.py`) and
writes the timings to `results/bench.json`:

```sh
npm run unit
npm run bench -- --rows 10000 --runs 7
```

## Status

Archived. parquet4abap was a lab exercise in taking one non-trivial ABAP code base through the
available toolchains. Its outcome is the decision to write our own ABAP-to-Go compiler, abap2go.
The decision is to be reviewed once abap2go is mature enough to compile this library. The
evaluation behind it, with how the abaplint transpiler and open-steamgate's Go target handle this
code, is in [docs/comparison.md](docs/comparison.md#outcome-our-own-compiler-abap2go).

The library is left as it was at that point: the reader and writer for flat tables work as
described above, and the milestones after A4 in [AGENDA.md](AGENDA.md) are not done.

## License

[MIT](LICENSE)
