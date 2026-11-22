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
| File structure (magic bytes, footer, row groups, column chunks, pages) | Planned |
| Thrift Compact Protocol (file metadata, page headers) | Done |
| Encodings: PLAIN, RLE / bit-packing hybrid, dictionary | Planned |
| Compression: uncompressed, GZIP | Planned |
| Compression: Snappy, ZSTD | Under consideration |
| Flat schemas | Planned |
| Nested schemas (repetition / definition levels) | Under consideration |

## Type mapping (draft)

| Parquet type | ABAP type |
|--------------|-----------|
| BOOLEAN | `abap_bool` |
| INT32 | `i` / `int4` |
| INT64 | `int8` |
| FLOAT / DOUBLE | `f` |
| BYTE_ARRAY (STRING) | `string` |
| BYTE_ARRAY | `xstring` |
| INT32 (DATE) | `d` |
| INT64 (TIMESTAMP) | `timestampl` |
| FIXED_LEN_BYTE_ARRAY / INT (DECIMAL) | `p` (packed) |

## Installation

Install the repository with [abapGit](https://abapgit.org/).

## Running the tests

The ABAP Unit tests in `src/` run outside an ABAP system on these toolchains:

| Command | Toolchain | Needs |
|---------|-----------|-------|
| `npm test` | abaplint, then the abaplint transpiler | Node, Git |
| `npm run osg` | open-steamgate, Go target | Node, Go, Git |

Run `npm install` first. `npm run unit` (part of `npm test`) clones the
[abaplint transpiler](https://github.com/abaplint/transpiler) into `tools/transpiler` at the commit
pinned in `tools/toolchains.lock.json`, builds it, and writes its result to `results/`. To try a
fork or a branch of the transpiler instead, point it at that checkout:
`npm run unit:local -- <dir>` uses the checkout as it is, and adding `--build` compiles it first.
Tests listed in `tools/known-gaps.json` fail on a toolchain for a known reason, each with its
upstream issue. They are reported as `KNOWN` and don't fail the run, and as `FIXED` once they
pass. The file has one section per toolchain: `abaplint-transpiler` and `open-steamgate-go`.

`npm run osg` clones open-steamgate into `tools/open-steamgate` at the commit pinned in
`tools/toolchains.lock.json`, sets it up, compiles the tests to Go and writes the result to
`results/osg-go-unit.json`. It works on Linux, macOS and native Windows. On Windows the runner adds the
workarounds in `tools/osg-win-paths.mjs` and `tools/osg-windows.patch`.

## Golden files

`testdata/golden/` holds small Parquet files written by pyarrow and DuckDB, each with a JSON file that
says what pyarrow reads from it. `tools/golden/generate.py` writes them, and also writes
`src/zparq2a_cl_golden.clas.abap`, a class for tests only that embeds the files, so the ABAP Unit
tests need no file access. To regenerate them with the versions pinned in
`tools/golden/requirements.txt`:

```sh
python -m venv tools/.venv
tools/.venv/Scripts/pip install -r tools/golden/requirements.txt   # Linux, macOS: tools/.venv/bin/pip
tools/.venv/Scripts/python tools/golden/generate.py
```

## Status

Early development. Expect the API to change.

## License

To be defined.
