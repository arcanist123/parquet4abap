# Toolchain comparison

parquet4abap runs the same ABAP source and ABAP Unit tests on several toolchains. This report
shows how each one handles that code. The plan behind it, and what each checkpoint covers, is in
[AGENDA.md](../AGENDA.md#track-b--toolchain-comparison). The report grows with each checkpoint.

| Checkpoint | After | Focus | State |
|------------|-------|-------|-------|
| [B1](#b1-integers-bit-operators-and-xstring) | A1, binary codec | Integer, bit-operator and `xstring` semantics; first micro-benchmarks | Done; micro-benchmarks pending |
| [B2](#b2-recursion-and-structures) | A2, Thrift and metadata codec | Recursion, structures | Done |
| B3 | A3/A4 | OO dispatch, RTTI, dynamic data, GZIP; first end-to-end throughput numbers | Not started |

OO dispatch moved from B2 to B3. In A2 the metadata codec calls the Thrift reader and writer
directly, so there is no dynamic dispatch to measure there. A3 adds encoders and compressors that
are chosen per column, behind interfaces.

## Toolchains and versions

| Toolchain | Version | How it runs |
|-----------|---------|-------------|
| ABAP platform | - | The reference for expected behaviour, based on the ABAP keyword documentation. It has no measured results or timings in this report. |
| abaplint transpiler | [arcanist123/transpiler@`1ff5131`](https://github.com/arcanist123/transpiler/tree/parquet4abap), 2.14.35 | `npm test`. The fork branch is upstream main plus our open fix pull requests (see [Issues](#issues-filed)). |
| open-steamgate, Go target | [oisee/open-steamgate@`9d2f052`](https://github.com/oisee/open-steamgate/commit/9d2f0529ea5ac9056d7c49c8f19166d14ad6c36b), Go 1.26.0 | `npm run osg`. On Windows, with the workarounds in `tools/osg-windows.patch` and `tools/osg-win-paths.mjs`. |

Both toolchains run on native Windows (x64, Node 26.13). The exact commits are pinned in
[tools/toolchains.lock.json](../tools/toolchains.lock.json), and the tests that fail for a known
reason are listed in [tools/known-gaps.json](../tools/known-gaps.json). To reproduce the numbers,
run the two commands above at the same commit as this report.

## Results

88 ABAP Unit tests in 9 classes, at the state of A2 with the B2 tests added.

| Class | Tests | abaplint transpiler | open-steamgate Go |
|-------|------:|--------------------:|------------------:|
| `ZPARQ2A_CL_BYTES` | 24 | 24 | 19 |
| `ZPARQ2A_CL_BIT_READER` | 7 | 7 | 6 |
| `ZPARQ2A_CL_BIT_WRITER` | 8 | 8 | 5 |
| `ZPARQ2A_CL_BYTE_READER` | 8 | 8 | 5 |
| `ZPARQ2A_CL_BYTE_WRITER` | 6 | 6 | 5 |
| `ZPARQ2A_CL_COMP_NONE` | 4 | 4 | 4 |
| `ZPARQ2A_CL_THRIFT_READER` | 14 | 14 | 1 |
| `ZPARQ2A_CL_THRIFT_WRITER` | 7 | 7 | 1 |
| `ZPARQ2A_CL_METADATA` | 10 | 10 | 0 |
| **Total** | **88** | **88** | **46** |

The transpiler passes every test, but only on the fork. On upstream main, 18 of the 85 tests at A2
failed, all for four bugs we have since fixed upstream or in open pull requests (see
[B1](#b1-integers-bit-operators-and-xstring)).

For open-steamgate, 42 tests fail for six known reasons. Only one of them gives a wrong result. The
others are either constructs the Go target can't compile yet, or a standard class it doesn't have:

| Kind | Issue | Tests | What happens |
|------|-------|------:|--------------|
| Not compiled | [#991](https://github.com/oisee/open-steamgate/issues/991) | 13 | A predicative method call as a condition: `IF o->m( ).`, `WHILE o->m( ).` |
| Not compiled | [#992](https://github.com/oisee/open-steamgate/issues/992) | 12 | The `REF #( )` constructor expression |
| Not compiled | [#540](https://github.com/oisee/open-steamgate/issues/540) | 7 | A method call on a new object: `NEW x( )->m( )` |
| Not compiled | [#993](https://github.com/oisee/open-steamgate/issues/993) | 1 | `LOOP AT itab REFERENCE INTO DATA(ref)` |
| Wrong result | [#989](https://github.com/oisee/open-steamgate/issues/989) | 4 | A leading minus applies to the whole expression: `- a - 1` is calculated as `- ( a - 1 )` |
| Missing library | [#990](https://github.com/oisee/open-steamgate/issues/990) | 5 | `CL_ABAP_CONV_CODEPAGE` can't create its converters, so UTF-8 encoding and decoding fail |

A test counts under the first issue that stops it. Many Thrift and metadata tests would hit
#991, #992 and #993 one after another. A construct the Go target can't compile in a method that
everything calls, such as the reader's `NEXT_FIELD` or the writer's `FLUSH_UNKNOWN`, stops every
test that reaches it. That's why only 2 of the 31 Thrift and metadata tests pass.

These are all constructs an ABAP developer writes every day. The library keeps using them, as
[AGENDA.md](../AGENDA.md#guiding-principles) asks, and the tests will pass as soon as the issues
are fixed.

## B1: integers, bit operators and `xstring`

A1 is the binary layer: little-endian integers, IEEE-754 floats, varints and ZigZag, UTF-8, the
RLE / bit-packing hybrid's bit reader and writer, and byte readers and writers over `xstring`.

| Area | Expected (ABAP documentation) | abaplint transpiler | open-steamgate Go |
|------|-------------------------------|---------------------|-------------------|
| `int8` edge values (±2^63, values above 2^53) | Exact | Exact on the fork. Upstream rounds `VALUE` with a literal above 2^53 ([#2150](https://github.com/abaplint/transpiler/issues/2150)). | Exact |
| Leading minus: `- a - 1` | `( - a ) - 1`: the sign binds tighter than `+ - * /` and weaker than `**` | Correct on the fork. Upstream calculates `- ( a - 1 )` ([#2170](https://github.com/abaplint/transpiler/issues/2170)). | `- ( a - 1 )` ([#989](https://github.com/oisee/open-steamgate/issues/989)) |
| `**` chains: `2 ** 3 ** 2` | 512 (right-associative) | Correct on the fork and now upstream too ([#2234](https://github.com/abaplint/transpiler/issues/2234), found while fixing #2170) | Not tested: the library only uses a single `**` |
| `int8` with `f` operands | Calculated in `f` | Correct on the fork. Upstream calculates in `int8`, which raises a RangeError or loses the fraction ([#2231](https://github.com/abaplint/transpiler/issues/2231)). | Correct |
| IEEE-754 bit patterns (subnormals, -0, limits) | Exact | Exact on the fork. Upstream fails here because of #2231. | Exact |
| Text literal passed to an `xsequence` parameter | Its bytes: `'010203'` is 3 bytes | Bytes on the fork. Upstream works on the characters ([#2232](https://github.com/abaplint/transpiler/issues/2232), now fixed upstream). | Correct |
| Bit packing and varints with `DIV` and `MOD` on `int8`, and `x` offset access | Byte-exact | Byte-exact | Byte-exact |
| UTF-8 via `CL_ABAP_CONV_CODEPAGE` | Available | Available (open-abap-core) | Not available ([#990](https://github.com/oisee/open-steamgate/issues/990)) |

The leading minus is the one bug both toolchains share. The ZigZag decoder uses `- a - 1`, so in
both cases the same varint tests fail.

**Micro-benchmarks:** not written yet. They will come with the benchmark program, see
[Not measured yet](#not-measured-yet).

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

## Static checks

The transpiler and open-steamgate both build on [abaplint](https://github.com/abaplint/abaplint),
and `npm test` runs abaplint's checks first. Two constructs are expected to be syntax errors per
the ABAP documentation, but abaplint's `check_syntax` accepts them:

- An HTML tag that ABAP Doc doesn't support, such as `<pre>`, in a class header
  ([abaplint#4655](https://github.com/abaplint/abaplint/issues/4655)).
- A text literal with non-hexadecimal content, such as `'XYZ'`, passed to an `xsequence`
  parameter ([abaplint#4656](https://github.com/abaplint/abaplint/issues/4656)).

## Footprint and setup

Wall-clock time for one full test run on the same Windows machine. These aren't benchmarks: they
include compiling the code, and a single run gives no spread.

| | abaplint transpiler | open-steamgate Go |
|---|---|---|
| Full test run (88 tests) | 8.4 s | 17.0 s |
| Breakdown | Transpile and run in Node | Front end 8.0 s on the first round, Go build 2.2 s, test binary 0.23 s |
| Setup | Clone and build from the pinned fork commit | Clone at the pinned commit, apply one patch, load one preload on Windows |

On native Windows, open-steamgate needs two workarounds before its unit runner finds any test
([#846](https://github.com/oisee/open-steamgate/issues/846),
[#987](https://github.com/oisee/open-steamgate/issues/987)). Its JavaScript path needs Developer
Mode for directory symlinks ([#988](https://github.com/oisee/open-steamgate/issues/988)); we
don't use that path. The transpiler needs no workarounds, but it needs the fork until its fixes
are merged.

When the Go target can't compile a construct, it names the construct and its source line, for
example `NOT_COMPILED in ZPARQ2A_CL_THRIFT_READER=>NEXT_FIELD (zparq2a_cl_thrift_reader.clas.abap:227):
REF constructor expression`. That made each issue above quick to reduce to a minimal reproduction.

## Not measured yet

- **Performance.** The benchmark program described in the agenda (`bench/zparq2a_benchmark.prog.abap`)
  writes and reads Parquet files, so it needs A3. The Thrift micro-benchmark would only run on the
  transpiler for now, because the Go target can't compile the metadata codec yet.
- **Peak memory and artifact size.** These start with the benchmark program.

## Issues filed

Every issue below has a minimal reproduction.

| Toolchain | Issue | State | Fix |
|-----------|-------|-------|-----|
| abaplint transpiler | [#2150](https://github.com/abaplint/transpiler/issues/2150) `VALUE` with an integer literal above 2^53 loses precision | Open | [#2151](https://github.com/abaplint/transpiler/pull/2151), open |
| abaplint transpiler | [#2170](https://github.com/abaplint/transpiler/issues/2170) A leading minus applies to the whole expression | Open | [#2233](https://github.com/abaplint/transpiler/pull/2233), open |
| abaplint transpiler | [#2231](https://github.com/abaplint/transpiler/issues/2231) `int8` with `f` operands is calculated as `int8` | Open | [#2237](https://github.com/abaplint/transpiler/pull/2237), open |
| abaplint transpiler | [#2232](https://github.com/abaplint/transpiler/issues/2232) A text literal passed to `xsequence` works on characters | Fixed | [#2236](https://github.com/abaplint/transpiler/pull/2236), merged |
| abaplint transpiler | [#2234](https://github.com/abaplint/transpiler/issues/2234) `**` is left-associative | Fixed | [#2235](https://github.com/abaplint/transpiler/pull/2235), merged |
| abaplint | [#4655](https://github.com/abaplint/abaplint/issues/4655) Unsupported HTML tag in a class header's ABAP Doc is accepted | Open | |
| abaplint | [#4656](https://github.com/abaplint/abaplint/issues/4656) A text literal for `xsequence` is not checked for hexadecimal content | Open | |
| open-steamgate | [#540](https://github.com/oisee/open-steamgate/issues/540) `NEW x( )->m( )` not compiled | Open | |
| open-steamgate | [#989](https://github.com/oisee/open-steamgate/issues/989) A leading minus applies to the whole expression | Open | |
| open-steamgate | [#990](https://github.com/oisee/open-steamgate/issues/990) `CL_ABAP_CONV_CODEPAGE` converters not compiled | Open | |
| open-steamgate | [#991](https://github.com/oisee/open-steamgate/issues/991) Predicative method call as a condition not compiled | Open | |
| open-steamgate | [#992](https://github.com/oisee/open-steamgate/issues/992) `REF #( )` not compiled | Open | |
| open-steamgate | [#993](https://github.com/oisee/open-steamgate/issues/993) `LOOP AT ... REFERENCE INTO` not compiled | Open | |
| open-steamgate | [#846](https://github.com/oisee/open-steamgate/issues/846), [#987](https://github.com/oisee/open-steamgate/issues/987), [#988](https://github.com/oisee/open-steamgate/issues/988) Native Windows | Open | Worked around locally |
