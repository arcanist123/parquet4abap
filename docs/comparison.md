# Toolchain comparison

parquet4abap runs the same ABAP source and ABAP Unit tests on several toolchains. This report
shows how each one handles that code. The plan behind it, and what each checkpoint covers, is in
[AGENDA.md](../AGENDA.md#track-b--toolchain-comparison). The report grows with each checkpoint.

| Checkpoint | After | Focus | State |
|------------|-------|-------|-------|
| [B1](#b1-integers-bit-operators-and-xstring) | A1, binary codec | Integer, bit-operator and `xstring` semantics; first micro-benchmarks | Done; micro-benchmarks pending |
| [B2](#b2-recursion-and-structures) | A2, Thrift and metadata codec | Recursion, structures | Done |
| [B3](#b3-oo-dispatch-rtti-dynamic-data-gzip-throughput) | A3/A4, writer and reader | OO dispatch, RTTI, dynamic data, GZIP; first end-to-end throughput numbers | Done; throughput on the transpiler only |
| [Outcome](#outcome-our-own-compiler-abap2go) | B3 | Which toolchain to build on | Our own ABAP-to-Go compiler, abap2go; to be reviewed once it can compile this library |

OO dispatch moved from B2 to B3. In A2 the metadata codec calls the Thrift reader and writer
directly, so there is no dynamic dispatch to measure there. A3 adds encoders and compressors that
are chosen per column, behind interfaces.

## Outcome: our own compiler, abap2go

parquet4abap was a lab exercise: take one non-trivial ABAP code base through the available
toolchains and see where each one stands. Its outcome is a decision. After B3 we looked at where
each toolchain is today and where it is heading, and decided to write an ABAP compiler of our own:
**abap2go**, which compiles ABAP to Go. The rest of this report is the evaluation that led there,
as it stood at B3.

With that, the exercise is complete and the repository is archived. The decision is to be
reviewed once abap2go is mature enough to compile this library.

What we weighed:

- **The abaplint transpiler** runs almost all of the library: 175 of 179 tests. But it runs ABAP
  on JavaScript, and the numbers show what that costs. Reading 10,000 rows takes about 2 s, and
  three of the four failures come from how the runtime does arithmetic on JavaScript numbers and
  BigInt (#2167, #2199, #2250). Upstream reviews and merges our fixes, but the execution model is
  not ours to change.
- **open-steamgate's Go target** is the direction we want: ABAP compiled to a native binary. Today
  it passes 86 of 179 tests and doesn't compile the writer's or the reader's main paths, so
  neither throughput nor dynamic data can be measured on it. Its gaps are constructs an ABAP
  developer writes every day, and none of our fix pull requests there has been merged, so fixing
  them ourselves helps only our fork. On native Windows it also needs local workarounds.

Neither gives us a compiled ABAP that runs this library today, and neither is one we can steer
towards it. abap2go is meant to close that gap. When it can compile the library, the review starts
from the same ABAP Unit tests, golden corpus and benchmark as this report. B4 and B5 are not run.

## Toolchains and versions

| Toolchain | Version | How it runs |
|-----------|---------|-------------|
| ABAP platform | - | The reference for expected behaviour, based on the ABAP keyword documentation. It has no measured results or timings in this report. |
| abaplint transpiler | [arcanist123/transpiler@`e6e0a6b`](https://github.com/arcanist123/transpiler/tree/parquet4abap), 2.14.35 | `npm run unit`, `npm run bench`. The fork branch is upstream main plus our open fix pull requests (see [Issues](#issues-filed)). |
| open-steamgate, Go target | [arcanist123/open-steamgate@`4f114ce`](https://github.com/arcanist123/open-steamgate/tree/parquet4abap), Go 1.26.0 | `npm run osg`, `npm run bench`. The fork branch is upstream main at `9d2f052` plus our fix pull requests #1000 to #1004, which are open. On Windows, with the workarounds in `tools/osg-windows.patch` and `tools/osg-win-paths.mjs`. |

Both toolchains run on native Windows (x64, Node 26.13). The exact commits are pinned in
[tools/toolchains.lock.json](../tools/toolchains.lock.json), and the tests that fail for a known
reason are listed in [tools/known-gaps.json](../tools/known-gaps.json). To reproduce the numbers,
run the commands above at the same commit as this report.

## Results

179 ABAP Unit tests in 19 classes, at the state of A4 with the B3 benchmark added.

| Class | Tests | abaplint transpiler | open-steamgate Go |
|-------|------:|--------------------:|------------------:|
| `ZPARQ2A_CL_BYTES` | 24 | 24 | 19 |
| `ZPARQ2A_CL_BIT_READER` | 7 | 7 | 7 |
| `ZPARQ2A_CL_BIT_WRITER` | 8 | 8 | 8 |
| `ZPARQ2A_CL_BYTE_READER` | 8 | 8 | 7 |
| `ZPARQ2A_CL_BYTE_WRITER` | 6 | 6 | 5 |
| `ZPARQ2A_CL_THRIFT_READER` | 14 | 14 | 2 |
| `ZPARQ2A_CL_THRIFT_WRITER` | 7 | 7 | 1 |
| `ZPARQ2A_CL_METADATA` | 10 | 10 | 0 |
| `ZPARQ2A_CL_COMP_NONE` | 4 | 4 | 4 |
| `ZPARQ2A_CL_COMP_GZIP` | 6 | 6 | 0 |
| `ZPARQ2A_CL_ENC_PLAIN` | 9 | 9 | 9 |
| `ZPARQ2A_CL_ENC_RLE` | 11 | 11 | 11 |
| `ZPARQ2A_CL_DEC_PLAIN` | 8 | 8 | 7 |
| `ZPARQ2A_CL_DEC_RLE` | 7 | 7 | 1 |
| `ZPARQ2A_CL_SCHEMA` | 9 | 8 | 3 |
| `ZPARQ2A_CL_WRITER` | 10 | 9 | 1 |
| `ZPARQ2A_CL_CHUNK_READER` | 7 | 7 | 0 |
| `ZPARQ2A_CL_READER` | 19 | 18 | 0 |
| `ZPARQ2A_CL_BENCHMARK` | 5 | 4 | 1 |
| **Total** | **179** | **175** | **86** |

On the transpiler, 4 tests fail for three known reasons, all with open issues:

| Kind | Issue | Tests | What happens |
|------|-------|------:|--------------|
| Wrong result | [#2199](https://github.com/abaplint/transpiler/issues/2199) | 2 | Types `b` and `s` (`int1`, `int2`) run as `i`: RTTI gives type kind `I`, and a value outside their range doesn't overflow |
| Wrong result | [#2167](https://github.com/abaplint/transpiler/issues/2167) | 1 | Arithmetic with `p` operands loses digits above 2^53 |
| Wrong result | [#2250](https://github.com/abaplint/transpiler/issues/2250) | 1 | `/` with an `int8` operand and a `p` target drops the fraction |

On upstream main more tests would fail, for the bugs whose fixes are still open pull requests:
[#2151](https://github.com/abaplint/transpiler/pull/2151), [#2237](https://github.com/abaplint/transpiler/pull/2237)
and [#2252](https://github.com/abaplint/transpiler/pull/2252).

For open-steamgate, 93 tests fail for 15 known reasons. A test counts under the first issue that
stops it:

| Kind | Issue | Tests | What happens |
|------|-------|------:|--------------|
| Not compiled | [#992](https://github.com/oisee/open-steamgate/issues/992) | 25 | The `REF #( )` constructor expression |
| Not compiled | [#991](https://github.com/oisee/open-steamgate/issues/991) | 17 | A predicative method call as a condition: `IF o->m( ).`, `WHILE o->m( ).` |
| Not compiled | [#1009](https://github.com/oisee/open-steamgate/issues/1009) | 11 | `DESCRIBE_BY_DATA` of a structure with a `REF TO f` or `REF TO string` component; later tests on the same type crash |
| Missing library | [#994](https://github.com/oisee/open-steamgate/issues/994) | 10 | `CL_ABAP_GZIP=>COMPRESS_BINARY_WITH_HEADER` is missing, so `ZPARQ2A_CL_COMP_GZIP` isn't compiled |
| Missing library | [#990](https://github.com/oisee/open-steamgate/issues/990) | 6 | `CL_ABAP_CONV_CODEPAGE` can't create its converters, so UTF-8 encoding and decoding fail |
| Not compiled | [#1006](https://github.com/oisee/open-steamgate/issues/1006) | 6 | `CONV d( )` as an operand of `+` or `-` |
| Wrong result | [#989](https://github.com/oisee/open-steamgate/issues/989) | 4 | A leading minus applies to the whole expression: `- a - 1` is calculated as `- ( a - 1 )` |
| Not compiled | [#1007](https://github.com/oisee/open-steamgate/issues/1007) | 3 | An `int8` moved into a generic `EXPORTING` parameter whose actual parameter is `i` |
| Not compiled | [#1008](https://github.com/oisee/open-steamgate/issues/1008) | 3 | `nmin( )` and `nmax( )` over `int8` |
| Not compiled | [#1005](https://github.com/oisee/open-steamgate/issues/1005) | 2 | A table expression with a nested component as key: `itab[ comp-sub = v ]` |
| Not compiled | [#1011](https://github.com/oisee/open-steamgate/issues/1011) | 2 | Reading through a data reference: `x = ref->*` |
| Not compiled | [#993](https://github.com/oisee/open-steamgate/issues/993) | 1 | `LOOP AT itab REFERENCE INTO DATA(ref)` |
| Not compiled | [#998](https://github.com/oisee/open-steamgate/issues/998) | 1 | `VALUE ty( FOR ... )` |
| Not compiled | [#999](https://github.com/oisee/open-steamgate/issues/999) | 1 | `decfloat34` |
| Not compiled | [#1010](https://github.com/oisee/open-steamgate/issues/1010) | 1 | A `VALUE` row given as a table expression: `VALUE ty( ( itab[ n ] ) )` |

Five more gaps are fixed on our fork branch: [#540](https://github.com/oisee/open-steamgate/issues/540)
(`NEW x( )->m( )`), [#995](https://github.com/oisee/open-steamgate/issues/995) (a generic value moved
into `int8`, `f`, `x` or `xstring`), [#996](https://github.com/oisee/open-steamgate/issues/996)
(`VALUE #( ... OPTIONAL )`), [#997](https://github.com/oisee/open-steamgate/issues/997) (`NEW #( )` for
a data reference) and the dictionary half of #998. That's why the bit writer and the byte reader
pass more tests than they did at B2. Upstream main has none of those fixes yet.

A construct the Go target can't compile in a method that everything calls stops every test that
reaches it. Every Parquet file needs a footer, and the Thrift writer that encodes it uses
`REF #( )`, so no test that writes a file passes on the Go target yet. Reading stops even earlier,
at #991 or #1009, so no test that reads a file passes either. These are all constructs an ABAP
developer writes every day. The library keeps
using them, as [AGENDA.md](../AGENDA.md#guiding-principles) asks, and the tests will pass as soon
as the issues are fixed.

## B1: integers, bit operators and `xstring`

A1 is the binary layer: little-endian integers, IEEE-754 floats, varints and ZigZag, UTF-8, the
RLE / bit-packing hybrid's bit reader and writer, and byte readers and writers over `xstring`.

| Area | Expected (ABAP documentation) | abaplint transpiler | open-steamgate Go |
|------|-------------------------------|---------------------|-------------------|
| `int8` edge values (±2^63, values above 2^53) | Exact | Exact on the fork. Upstream rounds `VALUE` with a literal above 2^53 ([#2150](https://github.com/abaplint/transpiler/issues/2150)). | Exact |
| Leading minus: `- a - 1` | `( - a ) - 1`: the sign binds tighter than `+ - * /` and weaker than `**` | Correct, fixed upstream ([#2170](https://github.com/abaplint/transpiler/issues/2170)). | `- ( a - 1 )` ([#989](https://github.com/oisee/open-steamgate/issues/989)) |
| `**` chains: `2 ** 3 ** 2` | 512 (right-associative) | Correct on the fork and now upstream too ([#2234](https://github.com/abaplint/transpiler/issues/2234), found while fixing #2170) | Not tested: the library only uses a single `**` |
| `int8` with `f` operands | Calculated in `f` | Correct on the fork. Upstream calculates in `int8`, which raises a RangeError or loses the fraction ([#2231](https://github.com/abaplint/transpiler/issues/2231)). | Correct |
| IEEE-754 bit patterns (subnormals, -0, limits) | Exact | Exact on the fork. Upstream fails here because of #2231. | Exact |
| Text literal passed to an `xsequence` parameter | Its bytes: `'010203'` is 3 bytes | Bytes on the fork. Upstream works on the characters ([#2232](https://github.com/abaplint/transpiler/issues/2232), now fixed upstream). | Correct |
| Bit packing and varints with `DIV` and `MOD` on `int8`, and `x` offset access | Byte-exact | Byte-exact | Byte-exact |
| UTF-8 via `CL_ABAP_CONV_CODEPAGE` | Available | Available (open-abap-core) | Not available ([#990](https://github.com/oisee/open-steamgate/issues/990)) |

The leading minus was the one bug both toolchains shared. The ZigZag decoder uses `- a - 1`, so the
same varint tests failed on both. The transpiler has fixed it since; open-steamgate hasn't yet.

**Micro-benchmarks:** not written yet, see [Not measured yet](#not-measured-yet).

## B2: recursion and structures

A2 adds the Thrift Compact Protocol and the Parquet metadata codec. The reader is recursive:
skipping a field it doesn't know walks nested structs, lists, sets and maps, up to a limit of 64
levels. The metadata is a tree of deep structures: `FileMetaData` has tables of row groups, those
have column chunks, which hold column metadata and statistics.

| Area | Tests | abaplint transpiler | open-steamgate Go |
|------|-------|---------------------|-------------------|
| Recursion to the nesting limit: 64 levels are accepted, 65 rejected, for structs and lists, three deep fields in a row, and inside a real footer | 4 | Pass | Not compiled (#991, #992) |
| Deep structures: decoding the golden footers into `ty_file_metadata` and checking it against what pyarrow reads | 1 | Pass | Not compiled (#991) |
| Byte-identical round trip of the golden footers and of every page header in the files | 2 | Pass | Not compiled (#991, #992) |
| Thrift details: field header deltas, booleans, unions, unknown fields kept as raw bytes, required fields, malformed input | 24 | Pass | 2 pass; the rest fail for #540, #989, #990, #991, #992 or #993 |

The golden corpus has 8 files from pyarrow 26.0.1 and DuckDB 2.0.1, see
[testdata/golden](../testdata/golden). They cover format v1 and v2 pages, dictionary encoding,
Snappy and GZIP, logical types, nested schemas, and files with column indexes, CRCs and bloom
filters. On the transpiler, every footer and page header decodes and encodes back to the same
bytes.

For recursion, the depth limit itself isn't what we're testing: 64 nested calls are well within
what any of the toolchains should handle. We're testing whether the depth count, which lives in an
instance attribute and changes on the way in and out, stays right through the recursion. On the
transpiler it does.

## B3: OO dispatch, RTTI, dynamic data, GZIP, throughput

A3 and A4 add the writer and the reader for flat tables. The schema comes from RTTI of the
table's line type, values go through encoders, decoders and compressors behind interfaces, and
the rows are read and written with dynamic data: `ASSIGN COMPONENT` by name, `CREATE DATA ...
TYPE HANDLE`, and generic `ANY TABLE` parameters.

| Area | Tests | abaplint transpiler | open-steamgate Go |
|------|-------|---------------------|-------------------|
| OO dispatch: calls through `ZPARQ2A_IF_ENCODER` and `ZPARQ2A_IF_COMPRESSOR` references (PLAIN and RLE encoders, no compression) | 24 | Pass | Pass |
| OO dispatch: a compressor chosen per column by the writer, one added to the reader, a chunk with the wrong compressor | 4 | Pass | Not compiled (#994, #1006) |
| RTTI: the schema from `DESCRIBE_BY_DATA` of the table, with type kinds, lengths, decimals, includes, and `REF TO` components as optional columns | 9 | 8 pass; `b` and `s` are described as `i` (#2199) | 3 pass; the rest stop at #998, #999, #1005 or #1006 |
| RTTI of target tables with `REF TO f` or `REF TO string` components, in the reader and benchmark tests | 11 | Pass | Not compiled (#1009) |
| Dynamic data: the writer reads each column with `ASSIGN COMPONENT`; the reader creates lines and optional values with `CREATE DATA ... TYPE HANDLE` and inserts into standard, sorted and hashed tables | 29 | 27 pass; #2167 and #2199 | Not reached: every write stops at #992 first, every read at #991 or #1009 |
| GZIP through `CL_ABAP_GZIP` | 6 | Pass (open-abap-core) | Missing (#994) |

Dispatch itself works on both toolchains. The 24 tests that call encoders and a compressor
through interface references pass on the Go target as well. The per-column tests stop at
something else before they get that far.

RTTI is where one of our fixes made a difference. In open-abap-core, the referenced type of
`REF TO data` wasn't a `CL_ABAP_ELEMDESCR`
([open-abap-core#1346](https://github.com/open-abap/open-abap-core/issues/1346)). That's fixed
upstream now ([#1347](https://github.com/open-abap/open-abap-core/pull/1347)), so the test of
unsupported line types passes.

For dynamic data, the transpiler passes everything except the two value checks above. On the
Go target, dynamic data isn't measured yet: no test gets as far as the first `ASSIGN COMPONENT`.

GZIP comes from `CL_ABAP_GZIP=>COMPRESS_BINARY_WITH_HEADER` and `DECOMPRESS_BINARY_WITH_HEADER`,
which write and read the gzip format of RFC 1952. open-abap-core has both, and the golden GZIP
files from pyarrow read correctly. open-steamgate's library doesn't have
`COMPRESS_BINARY_WITH_HEADER`, so no method of `ZPARQ2A_CL_COMP_GZIP` is compiled, and no program
that refers to the class can be built.

### Throughput

The benchmark is [`ZPARQ2A_CL_BENCHMARK`](../src/zparq2a_cl_benchmark.clas.abap). It generates a
table from a seed, writes it with `ZPARQ2A_CL_WRITER`, reads the file back with `ZPARQ2A_CL_READER`,
compares the rows, and times the write and the read with `GET RUN TIME FIELD`. A row has 8
columns: `i`, `int8`, `p LENGTH 8 DECIMALS 2`, `f`, `abap_bool`, `string`, `d`, and an optional
`REF TO string` that is null in every fourth row. The report
[`ZPARQ2A_BENCHMARK`](../src/zparq2a_benchmark.prog.abap) runs it, with parameters for the row
count, the seed, the number of runs, GZIP, and a file for the result.

`npm run bench` ([tools/run-bench.mjs](../tools/run-bench.mjs)) runs it on both toolchains. On the
transpiler it calls the class in the transpiled code. On the Go target it builds the report into
a native executable with `osabap`. Then [tools/bench/check.py](../tools/bench/check.py) reads each
file with pyarrow and compares every value with its own copy of the generator.

10,000 rows, seed 1, the median of 7 runs, on the transpiler:

| | File | Write | Read |
|---|---:|---:|---:|
| Uncompressed | 538,853 bytes | 619 ms: 16,200 rows/s, 0.87 MB/s | 1,999 ms: 5,000 rows/s, 0.27 MB/s |
| GZIP | 181,781 bytes | 597 ms: 16,700 rows/s, 0.30 MB/s | 1,933 ms: 5,200 rows/s, 0.09 MB/s |

MB/s is file bytes (10^6) per second. The first of the 7 runs is about a third slower than the
rest, while Node compiles the code; the median leaves it out. GZIP adds no measurable time,
because compression and decompression run in Node's zlib, not in ABAP.

The first run of the benchmark found a performance bug. The write time grew with the square of
the row count, and a profile put 75 to 90 % of it in one regular expression: `CONCATENATE ...
IN BYTE MODE` into an `xstring` checked the whole result again on every append
([#2251](https://github.com/abaplint/transpiler/issues/2251)). The byte writer builds every page
that way. With the fix ([#2252](https://github.com/abaplint/transpiler/pull/2252), on our fork
branch), the write is linear:

| Rows | Write before #2252 | Write with #2252 | Read |
|-----:|---:|---:|---:|
| 2,500 | 718 ms | | 570 ms |
| 5,000 | 2,360 ms | | 1,126 ms |
| 10,000 | 10,152 ms | 619 ms | 1,999 ms |
| 20,000 | 43,215 ms | | 4,297 ms |

The read was linear all along. Its time is spread over the runtime's structure copies,
assignments and comparisons, with no single hot spot.

pyarrow reads both files and finds every value as generated, except in the `price` column.
There, `next( ) MOD 100000000 / 100` into a `p` field drops the fraction on the transpiler: the
`int8` operand makes the runtime divide in BigInt
([#2250](https://github.com/abaplint/transpiler/issues/2250)). The writer and the reader handle
the values they get correctly; it's the generated values that are wrong. This is also the one
benchmark unit test that fails on the transpiler. And for the same reason, the uncompressed
benchmark file doesn't have the same bytes on every toolchain yet.

On the Go target the benchmark doesn't run. `osabap` stops building the report at #994, because
the report refers to `ZPARQ2A_CL_COMP_GZIP`. Past that, every write would stop at #992, and the
comparison of the rows at #1011. The build also needed one more Windows workaround: `osabap.mjs`
passes raw paths to `import( )`, as reported for another tool in
[#782](https://github.com/oisee/open-steamgate/issues/782). `tools/osg-windows.patch` now fixes
those calls too.

## Static checks

The transpiler and open-steamgate both build on [abaplint](https://github.com/abaplint/abaplint),
and `npm test` runs abaplint's checks first. abaplint's `check_syntax` accepted three constructs
that are syntax errors per the ABAP documentation. Two of them are fixed upstream:

- An HTML tag that ABAP Doc doesn't support, such as `<pre>`, in a class header
  ([abaplint#4655](https://github.com/abaplint/abaplint/issues/4655), open).
- A text literal with non-hexadecimal content, such as `'XYZ'`, passed to an `xsequence`
  parameter ([abaplint#4656](https://github.com/abaplint/abaplint/issues/4656), fixed).
- A `VALUE` row `( dobj )` of another numeric type than the table's elementary line type
  ([abaplint#4648](https://github.com/abaplint/abaplint/issues/4648), fixed).

## Footprint and setup

Wall-clock time for one full test run on the same Windows machine. These aren't benchmarks: they
include compiling the code, and a single run gives no spread.

| | abaplint transpiler | open-steamgate Go |
|---|---|---|
| Full test run (179 tests) | 7.8 s | 78.3 s |
| Benchmark report | Not built: the transpiler can't pass parameters to a report, so `npm run bench` calls the class | `osabap` stops after 6.8 s (#994) |
| Setup | Clone and build from the pinned fork commit | Clone at the pinned commit, apply one patch, load one preload on Windows |

At B2 the Go run took 17 s for 88 tests. It now compiles more than twice as many classes,
including the writer and the reader.

On native Windows, open-steamgate needs two workarounds before its unit runner finds any test
([#846](https://github.com/oisee/open-steamgate/issues/846),
[#987](https://github.com/oisee/open-steamgate/issues/987)), and one more for `osabap`
([#782](https://github.com/oisee/open-steamgate/issues/782)). Its JavaScript path needs Developer
Mode for directory symlinks ([#988](https://github.com/oisee/open-steamgate/issues/988)); we
don't use that path. The transpiler needs no workarounds, but it needs the fork until its fixes
are merged.

When the Go target can't compile a construct, it names the construct and its source line, for
example `NOT_COMPILED in ZPARQ2A_CL_THRIFT_WRITER=>FLUSH_UNKNOWN (zparq2a_cl_thrift_writer.clas.abap:375):
REF constructor expression`. That made each issue above quick to reduce to a minimal reproduction.

## Not measured yet

- **Throughput on the Go target.** It needs #994, #992 and #1011 first, see [Throughput](#throughput).
- **Micro-benchmarks** for bit packing, varints and Thrift. The Thrift one would only run on the
  transpiler for now, because the Go target can't compile the metadata codec yet.
- **Peak memory and artifact size.**

## Issues filed

Every issue below has a minimal reproduction.

| Toolchain | Issue | State | Fix |
|-----------|-------|-------|-----|
| abaplint transpiler | [#2150](https://github.com/abaplint/transpiler/issues/2150) `VALUE` with an integer literal above 2^53 loses precision | Open | [#2151](https://github.com/abaplint/transpiler/pull/2151), open |
| abaplint transpiler | [#2167](https://github.com/abaplint/transpiler/issues/2167) Arithmetic with `p` operands loses digits above 2^53 | Open | |
| abaplint transpiler | [#2170](https://github.com/abaplint/transpiler/issues/2170) A leading minus applies to the whole expression | Fixed | [#2233](https://github.com/abaplint/transpiler/pull/2233), merged |
| abaplint transpiler | [#2199](https://github.com/abaplint/transpiler/issues/2199) Types `b` and `s` run as `i` | Open | |
| abaplint transpiler | [#2231](https://github.com/abaplint/transpiler/issues/2231) `int8` with `f` operands is calculated as `int8` | Open | [#2237](https://github.com/abaplint/transpiler/pull/2237), open |
| abaplint transpiler | [#2232](https://github.com/abaplint/transpiler/issues/2232) A text literal passed to `xsequence` works on characters | Fixed | [#2236](https://github.com/abaplint/transpiler/pull/2236), merged |
| abaplint transpiler | [#2234](https://github.com/abaplint/transpiler/issues/2234) `**` is left-associative | Fixed | [#2235](https://github.com/abaplint/transpiler/pull/2235), merged |
| abaplint transpiler | [#2242](https://github.com/abaplint/transpiler/issues/2242) `int8` assigned to `d` or `t` fails | Open | [#2243](https://github.com/abaplint/transpiler/pull/2243), open |
| abaplint transpiler | [#2250](https://github.com/abaplint/transpiler/issues/2250) `/` with an `int8` operand and a `p` target drops the fraction | Open | |
| abaplint transpiler | [#2251](https://github.com/abaplint/transpiler/issues/2251) Appending to an `xstring` with `CONCATENATE IN BYTE MODE` is quadratic | Open | [#2252](https://github.com/abaplint/transpiler/pull/2252), open |
| open-abap-core | [#1346](https://github.com/open-abap/open-abap-core/issues/1346) The referenced type of `REF TO data` is not a `CL_ABAP_ELEMDESCR` | Fixed | [#1347](https://github.com/open-abap/open-abap-core/pull/1347), merged |
| abaplint | [#4648](https://github.com/abaplint/abaplint/issues/4648) A `VALUE` row of another numeric type is accepted | Fixed | |
| abaplint | [#4655](https://github.com/abaplint/abaplint/issues/4655) Unsupported HTML tag in a class header's ABAP Doc is accepted | Open | |
| abaplint | [#4656](https://github.com/abaplint/abaplint/issues/4656) A text literal for `xsequence` is not checked for hexadecimal content | Fixed | |
| open-steamgate | [#540](https://github.com/oisee/open-steamgate/issues/540) `NEW x( )->m( )` not compiled | Open | [#1000](https://github.com/oisee/open-steamgate/pull/1000), open |
| open-steamgate | [#989](https://github.com/oisee/open-steamgate/issues/989) A leading minus applies to the whole expression | Open | |
| open-steamgate | [#990](https://github.com/oisee/open-steamgate/issues/990) `CL_ABAP_CONV_CODEPAGE` converters not compiled | Open | |
| open-steamgate | [#991](https://github.com/oisee/open-steamgate/issues/991) Predicative method call as a condition not compiled | Open | |
| open-steamgate | [#992](https://github.com/oisee/open-steamgate/issues/992) `REF #( )` not compiled | Open | |
| open-steamgate | [#993](https://github.com/oisee/open-steamgate/issues/993) `LOOP AT ... REFERENCE INTO` not compiled | Open | |
| open-steamgate | [#994](https://github.com/oisee/open-steamgate/issues/994) `CL_ABAP_GZIP=>COMPRESS_BINARY_WITH_HEADER` missing | Open | |
| open-steamgate | [#995](https://github.com/oisee/open-steamgate/issues/995) A generic value moved into `int8`, `f`, `x` or `xstring` not compiled | Open | [#1001](https://github.com/oisee/open-steamgate/pull/1001), open |
| open-steamgate | [#996](https://github.com/oisee/open-steamgate/issues/996) `VALUE #( ... OPTIONAL )` and `DEFAULT` not compiled | Open | [#1002](https://github.com/oisee/open-steamgate/pull/1002), open |
| open-steamgate | [#997](https://github.com/oisee/open-steamgate/issues/997) `NEW #( )` for a data reference not compiled | Open | [#1003](https://github.com/oisee/open-steamgate/pull/1003), open |
| open-steamgate | [#998](https://github.com/oisee/open-steamgate/issues/998) `VALUE string_table( )` and `VALUE ty( FOR ... )` not compiled | Open | [#1004](https://github.com/oisee/open-steamgate/pull/1004) for the first, open |
| open-steamgate | [#999](https://github.com/oisee/open-steamgate/issues/999) `decfloat34` not compiled | Open | |
| open-steamgate | [#1005](https://github.com/oisee/open-steamgate/issues/1005) A table expression with a nested key component not compiled | Open | |
| open-steamgate | [#1006](https://github.com/oisee/open-steamgate/issues/1006) `CONV d( )` as an operand of `+` or `-` not compiled | Open | |
| open-steamgate | [#1007](https://github.com/oisee/open-steamgate/issues/1007) `int8` into a generic `EXPORTING` parameter with an `i` actual not compiled | Open | |
| open-steamgate | [#1008](https://github.com/oisee/open-steamgate/issues/1008) `nmin( )` and `nmax( )` over `int8` not compiled | Open | |
| open-steamgate | [#1009](https://github.com/oisee/open-steamgate/issues/1009) `DESCRIBE_BY_DATA` of a `REF TO f` or `REF TO string` component not compiled | Open | |
| open-steamgate | [#1010](https://github.com/oisee/open-steamgate/issues/1010) A `VALUE` row given as a table expression not compiled | Open | |
| open-steamgate | [#1011](https://github.com/oisee/open-steamgate/issues/1011) Reading through a data reference, `x = ref->*`, not compiled | Open | |
| open-steamgate | [#782](https://github.com/oisee/open-steamgate/issues/782), [#846](https://github.com/oisee/open-steamgate/issues/846), [#987](https://github.com/oisee/open-steamgate/issues/987), [#988](https://github.com/oisee/open-steamgate/issues/988) Native Windows | Open | Worked around locally |
