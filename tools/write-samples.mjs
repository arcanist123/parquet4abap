#!/usr/bin/env node
// Writes the sample files of ZPARQ2A_CL_SAMPLES with the code the abaplint
// transpiler built into output/, one <name>.parquet per sample.
//
//   node tools/write-samples.mjs [DIR]
//
// Run `npm run unit` first, so output/ holds the transpiled source. DIR defaults
// to results/samples. tools/writer/check.py then reads the files with pyarrow
// and DuckDB.
//
// Exit code: 0 when every sample was written, 1 when the writer raised an error,
// 4 when output/ is missing.
import {existsSync, mkdirSync, writeFileSync} from "node:fs";
import {dirname, join, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = join(repoRoot, "output");
const target = resolve(process.argv[2] ?? join(repoRoot, "results", "samples"));
const module = join(outputDir, "project", "zparq2a_cl_samples.clas.mjs");

if (!existsSync(module)) {
  console.error("write-samples: output/ has no ZPARQ2A_CL_SAMPLES; run `npm run unit` first");
  process.exit(4);
}

await import(pathToFileURL(join(outputDir, "init.mjs")).href);
const {zparq2a_cl_samples: samples} = await import(pathToFileURL(module).href);

let files;
try {
  files = await samples.files();
} catch (error) {
  // an ABAP exception carries its text in the attribute TEXT
  const text = error?.text?.get?.() ?? error?.message ?? String(error);
  console.error(`write-samples: ZPARQ2A_CL_SAMPLES=>FILES raised ${error?.constructor?.name ?? "an error"}: ${text}`);
  process.exit(1);
}

mkdirSync(target, {recursive: true});
for (const row of files.array()) {
  const name = row.get().name.get();
  const bytes = Buffer.from(row.get().data.get(), "hex");
  writeFileSync(join(target, `${name}.parquet`), bytes);
  console.log(`${name.padEnd(14)} ${String(bytes.length).padStart(6)} bytes`);
}
console.log(`write-samples: ${files.array().length} files in ${target}`);
