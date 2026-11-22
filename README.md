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
| Thrift Compact Protocol (file metadata) | Planned |
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

## Status

Early development. Expect the API to change.

## License

To be defined.
