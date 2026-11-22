# parquet4abap — Agenda

## Purpose

The project has two goals of equal weight:

1. **A working Parquet library in native ABAP.** Read and write Apache Parquet files from ABAP
   internal tables, in memory, with no external tools, middleware or kernel extensions.
2. **A reference scenario and demo for ABAP toolchains.** The same source code is built and run
   on three toolchains: the ABAP platform (installed with abapGit), open-steamgate and the
   abaplint transpiler. The project reports where each toolchain handles real-world ABAP
   correctly, where it falls short, and how fast it runs. It also serves as a worked example of
   taking one non-trivial ABAP code base through each toolchain.

Parquet fits the second goal well. It needs byte- and bit-level work on `xstring`, integer
arithmetic near overflow, IEEE-754 floats, a recursive binary protocol (Thrift), RTTI-driven
generic code, OO with interfaces, and compression. It also has an outside oracle: any Parquet file
we write can be checked with independent tools such as pyarrow or DuckDB.

## Guiding principles

- **One code base.** Every toolchain runs the same abapGit-serialized source. We don't keep
  separate branches or copies per toolchain.
- **Plain, idiomatic ABAP.** We write the code the way an ABAP developer would. We don't avoid
  language features just to suit a toolchain, because gaps in the toolchains are what the
  comparison is meant to find.
- **Workarounds are visible.** If a toolchain can't handle a construct, we log an issue with a
  minimal reproduction. A workaround goes in only when it doesn't make the ABAP worse, and it
  points to that issue.
- **No host coupling.** The core API takes and returns `xstring` and internal tables. We avoid
  database access, file system calls, GUI and RFC. Anything that depends on the platform, such as
  GZIP via `cl_abap_gzip`, sits behind an interface so each toolchain can plug in what it supports.
- **External oracle.** Correctness is measured against golden Parquet files and against reads by
  independent Parquet implementations, not only against our own round trips.

## Architecture (summary)

| Component | Responsibility |
|-----------|----------------|
| `ZCL_PARQUET_BYTES` | Little-endian INT32/INT64, FLOAT/DOUBLE, varint/ZigZag, UTF-8, bit streams (1..32 bits) over `xstring` |
| `ZCL_PARQUET_THRIFT` | Thrift Compact Protocol for `FileMetaData`, `SchemaElement`, `RowGroup`, `ColumnChunk`, `ColumnMetaData`, `PageHeader` |
| `ZIF_PARQUET_ENCODER` | `ZCL_PARQUET_ENC_PLAIN`, `ZCL_PARQUET_ENC_RLE` (RLE / bit-packing hybrid for levels and dictionary indices) |
| `ZIF_PARQUET_COMPRESSOR` | `ZCL_PARQUET_COMP_NONE`, `ZCL_PARQUET_COMP_GZIP`; later pure-ABAP Snappy / ZSTD |
| `ZCL_PARQUET_SCHEMA` | RTTI mapping of ABAP types (`I`, `INT8`, `P`, `F`, `DECFLOAT34`, `C`, `STRING`, `X`, `XSTRING`, `D`, `T`) to Parquet physical and logical types |
| `ZCL_PARQUET_WRITER` / `ZCL_PARQUET_READER` | Public in-memory entry points: internal table ↔ Parquet `xstring` |

## Track A — Parquet library milestones

| # | Milestone | Scope | Done when |
|---|-----------|-------|-----------|
| A0 | Skeleton | Packages, interfaces, ABAP Unit setup, abaplint config | Empty test suite builds in every toolchain |
| A1 | Binary codec | `ZCL_PARQUET_BYTES` incl. bit streams, varint, ZigZag | Unit tests cover edge values (0, -1, min/max INT32/INT64, NaN, ±∞, subnormals) |
| A2 | Thrift compact | Encode/decode the metadata structs | Footers of golden files decode, and re-encoding gives the same bytes |
| A3 | MVP writer | Flat tables, PLAIN, uncompressed + GZIP, optional columns (definition levels) | pyarrow and DuckDB read our output and the values match |
| A4 | MVP reader | Same scope in reverse | Golden files from pyarrow read into the expected internal tables; round-trip tests pass |
| A5 | Dictionary encoding | `RLE_DICTIONARY` read and write | Golden dictionary-encoded files read correctly |
| A6 | Snappy | Pure-ABAP Snappy | Default pyarrow output (Snappy) reads correctly |
| A7 | Scale | Multiple row groups, page-size limits, streaming-friendly API | Large datasets processed in bounded memory |
| A8 | Nested types | `STRUCT` / `LIST` with repetition levels | Golden nested files round-trip |
| A9 | Release 1.0 | Stable API, docs, license | Tagged release installable with abapGit |

## Track B — Toolchain comparison

### Target toolchains

The same library source, with its ABAP Unit tests, must run unchanged on three toolchains:

1. **ABAP platform**: the library installed with abapGit
2. **open-steamgate** ([oisee/open-steamgate](https://github.com/oisee/open-steamgate))
3. **abaplint transpiler** ([abaplint/transpiler](https://github.com/abaplint/transpiler))

Each run records the exact version (commit or release tag) of the toolchain it used.

The ABAP platform is the reference for language semantics. Its column in the reports gives the
*expected* behaviour, based on the ABAP keyword documentation and common experience, and carries
no benchmark numbers. Measured results and performance figures cover open-steamgate and the
abaplint transpiler only.

### What we measure

| Dimension | Question | Metric |
|-----------|----------|--------|
| Language coverage | Does the code build and run without changes? | Number of constructs that fail, each with a minimal reproduction |
| Correctness | Are the results identical? | ABAP Unit pass rate; byte-identical writer output on all toolchains; golden-file pass rate |
| Semantics | Are ABAP edge cases preserved? | Targeted tests: integer overflow, `p` rounding, `f` formatting, `c` padding and truncation, `xstring` offset/length access, `BIT-*` operators, type conversion rules |
| Library coverage | Which standard classes are available? | Availability of RTTI (`cl_abap_*descr`), `cl_abap_gzip`, `cl_abap_conv_codepage`, and similar |
| Performance | How fast is it? | Write/read throughput (MB/s, rows/s) on fixed datasets; separate micro-benchmarks for bit packing, varint and Thrift |
| Footprint | What does it cost to run? | Build time, artifact size, peak memory |
| Developer experience | How usable is the toolchain day to day? | Quality of error messages, debugging, setup steps |

### Harness

- **Shared test suite:** the ABAP Unit tests are the single source of truth and run unchanged on
  every toolchain.
- **Golden corpus:** a versioned set of Parquet files produced with pyarrow and DuckDB, each with
  a JSON description of its expected contents. A generator script makes the corpus reproducible.
- **Benchmark program:** a fixed ABAP entry point that generates deterministic data (seeded),
  writes it, reads it back, and prints timings in a machine-readable format.
- **Runner scripts:** one script per toolchain (build → test → benchmark) that collect results
  into a common format.
- **CI:** run all toolchains on every push and publish a results table.

### Comparison checkpoints

Each Track A milestone ends with a Track B checkpoint, so results build up step by step:

| Checkpoint | After | Focus |
|------------|-------|-------|
| B1 | A1 | Integer, bit-operator and `xstring` semantics; first micro-benchmarks |
| B2 | A2 | Recursion, structures, OO dispatch |
| B3 | A3/A4 | RTTI, dynamic data (`ASSIGN COMPONENT`, `CREATE DATA`), GZIP availability; first end-to-end throughput numbers |
| B4 | A6 | CPU-heavy pure-ABAP compression: the main performance comparison |
| B5 | A7/A8 | Memory behaviour at scale; nested generic code |

### Deliverables

- `docs/comparison.md`: a results report, updated at each checkpoint
- An issue for each toolchain gap, with a minimal ABAP reproduction, reported upstream where
  that makes sense
- Benchmark datasets and scripts that anyone can rerun
- A short guide for each toolchain: how to set it up, build, run the tests and run the benchmark

## Repository layout (proposed)

```
src/                 abapGit-serialized ABAP (library + unit tests)
bench/               benchmark entry point and datasets
testdata/golden/     golden Parquet files + expected-content JSON
tools/               corpus generator (Python), per-toolchain runner scripts
docs/                design notes, comparison report
```

## Open questions

- Which language version to target: Standard ABAP only, or also ABAP for Cloud Development?
- Do we need a pure-ABAP DEFLATE so GZIP works where `cl_abap_gzip` is missing?
- Which public API shape: static helpers, a builder, or both?
- Which license?
- What size of benchmark dataset is meaningful while staying cheap to run in CI?
