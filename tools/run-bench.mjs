#!/usr/bin/env node
// Runs the end-to-end benchmark, ZPARQ2A_CL_BENCHMARK, on the toolchains and
// writes the result to results/bench.json.
//
//   node tools/run-bench.mjs [--rows N] [--runs N] [--seed N] [--toolchain NAME...]
//
// Each toolchain writes and reads the same generated table RUNS times, without
// compression and with GZIP; the ABAP code times itself with GET RUN TIME FIELD.
// abaplint-transpiler calls the class in the code `npm run unit` transpiled into
// output/, so run that first. open-steamgate-go builds the report
// ZPARQ2A_BENCHMARK into a native executable with osabap and runs it (set up the
// checkout with `npm run osg` first). The file of the last run goes to
// results/bench/ and tools/bench/check.py compares it with pyarrow.
//
// Defaults: 10000 rows, 5 runs, seed 1, both toolchains.
// Exit code: 0 when every toolchain ran, 1 otherwise, 4 on a usage error.
import {spawnSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import {join} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";
import {lock, osgRoot, repoRoot, tidy, toolchainEnv, windows} from "./osg-env.mjs";

const toolchains = ["abaplint-transpiler", "open-steamgate-go"];
const codecs = ["none", "gzip"];
const benchDir = join(repoRoot, "results", "bench");
const python = join(repoRoot, "tools", ".venv", windows ? "Scripts/python.exe" : "bin/python");

function parseArgs(argv) {
  const options = {rows: 10000, runs: 5, seed: 1, toolchains: []};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 17).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
      process.exit(0);
    } else if (["--rows", "--runs", "--seed"].includes(arg)) {
      const value = Number(argv[++i]);
      if (!Number.isInteger(value) || (arg !== "--seed" && value < 1)) usage(`${arg} needs a positive integer`);
      options[arg.slice(2)] = value;
    } else if (arg === "--toolchain") {
      while (argv[i + 1] && !argv[i + 1].startsWith("--")) options.toolchains.push(argv[++i]);
    } else usage(`unexpected argument: ${arg}`);
  }
  for (const name of options.toolchains) if (!toolchains.includes(name)) usage(`unknown toolchain ${name}`);
  if (!options.toolchains.length) options.toolchains = toolchains;
  return options;
}

function usage(message) {
  console.error(`run-bench: ${message}`);
  process.exit(4);
}

function log(message) {
  console.error(`run-bench: ${message}`);
}

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};

// rows/s and MB/s from the median time of the runs; MB is 10^6 bytes of the file
function summarize(runs) {
  const rows = runs[0].rows;
  const bytes = runs[0].bytes;
  const speed = (us) => ({medianUs: us, rowsPerSecond: Math.round(rows / (us / 1e6)), mbPerSecond: Number((bytes / us).toFixed(2))});
  return {rows, bytes, write: speed(median(runs.map((r) => r.write_us))), read: speed(median(runs.map((r) => r.read_us)))};
}

function checkFile(file, options) {
  if (!existsSync(python)) return {status: "SKIPPED", message: "tools/.venv not set up"};
  const result = spawnSync(python, [join(repoRoot, "tools", "bench", "check.py"), file, String(options.rows), String(options.seed)], {encoding: "utf8"});
  const message = (result.stdout || result.stderr).trim();
  return {status: result.status === 0 ? "OK" : "DIFFERENT", message};
}

async function runTranspiler(options) {
  const module = join(repoRoot, "output", "project", "zparq2a_cl_benchmark.clas.mjs");
  if (!existsSync(module)) return {status: "NOT_BUILT", message: "output/ has no ZPARQ2A_CL_BENCHMARK; run `npm run unit` first"};
  await import(pathToFileURL(join(repoRoot, "output", "init.mjs")).href);
  const lockEntry = JSON.parse(readFileSync(join(repoRoot, "tools", "toolchains.lock.json"), "utf8"))["abaplint-transpiler"];
  const abap = globalThis.abap;
  const result = {version: {repo: lockEntry.repo, commit: lockEntry.commit}, codecs: {}};
  for (const codec of codecs) {
    try {
      const benchmark = await new abap.Classes["ZPARQ2A_CL_BENCHMARK"]().constructor_({seed: new abap.types.Integer().set(options.seed)});
      const rows = await benchmark.rows({count: new abap.types.Integer().set(options.rows)});
      const className = codec === "gzip" ? "ZPARQ2A_CL_COMP_GZIP" : "ZPARQ2A_CL_COMP_NONE";
      const compressor = new abap.types.ABAPObject().set(await new abap.Classes[className]().constructor_());
      const runs = [];
      let file;
      for (let i = 0; i < options.runs; i++) {
        const run = (await benchmark.run({rows, compressor})).get();
        runs.push({rows: run.rows.get(), bytes: run.bytes.get(), write_us: run.write_us.get(), read_us: run.read_us.get()});
        file = run.file.get();
      }
      const path = join(benchDir, `abaplint-transpiler-${codec}.parquet`);
      writeFileSync(path, Buffer.from(file, "hex"));
      result.codecs[codec] = {runs, ...summarize(runs), oracle: checkFile(path, options)};
    } catch (error) {
      const text = error?.text?.get?.() ?? error?.message ?? String(error);
      result.codecs[codec] = {status: "ERROR", message: text};
    }
  }
  const failed = Object.values(result.codecs).some((c) => c.status);
  return {status: failed ? "ERROR" : "OK", ...result};
}

function runOsg(options) {
  if (!existsSync(join(osgRoot, "node_modules"))) return {status: "NOT_BUILT", message: "tools/open-steamgate is not set up; run `npm run osg` first"};
  const env = toolchainEnv();
  const version = {repo: lock.repo, commit: lock.commit, go: lock.go};
  log("open-steamgate Go target: building ZPARQ2A_BENCHMARK with osabap");
  const started = Date.now();
  const build = spawnSync("node", ["tools/gogen/osabap.mjs", tidy(join(repoRoot, "src", "zparq2a_benchmark.prog.abap"))],
    {cwd: osgRoot, env, encoding: "utf8", maxBuffer: 256 * 1024 * 1024});
  const buildMs = Date.now() - started;
  const binary = join(osgRoot, "tools", "gogen", ".out", windows ? "osabap.exe" : "osabap");
  if (build.status !== 0) {
    // the first line that names the problem, without the Node stack
    const message = (build.stderr || build.stdout).split(/\r?\n/).find((l) => /^(Error|NOT_COMPILED)|error:/i.test(l.trim())) ?? `exit ${build.status}`;
    return {status: "NOT_BUILT", version, buildMs, message: message.trim()};
  }
  const result = {version, buildMs, codecs: {}};
  for (const codec of codecs) {
    const path = join(benchDir, `open-steamgate-go-${codec}.parquet`);
    rmSync(path, {force: true});
    const args = ["--rows", options.rows, "--seed", options.seed, "--runs", options.runs, "--file", tidy(path), ...(codec === "gzip" ? ["--gzip"] : [])].map(String);
    const child = spawnSync(binary, args, {encoding: "utf8"});
    const runs = [];
    for (const line of child.stdout.split(/\r?\n/)) {
      const pairs = Object.fromEntries([...line.matchAll(/(\w+)=(\S+)/g)].map((m) => [m[1], m[2]]));
      if (pairs.run) runs.push({rows: Number(pairs.rows), bytes: Number(pairs.bytes), write_us: Number(pairs.write_us), read_us: Number(pairs.read_us)});
    }
    if (runs.length !== options.runs) {
      const message = child.stdout.split(/\r?\n/).find((l) => l.startsWith("error=")) ?? (child.stderr.trim() || `exit ${child.status}`);
      result.codecs[codec] = {status: "ERROR", message};
      continue;
    }
    result.codecs[codec] = {runs, ...summarize(runs), oracle: existsSync(path) ? checkFile(path, options) : {status: "MISSING"}};
  }
  const failed = Object.values(result.codecs).some((c) => c.status);
  return {status: failed ? "ERROR" : "OK", ...result};
}

function print(name, result) {
  if (!result.codecs) {
    console.log(`${name.padEnd(20)} ${result.status}: ${result.message}`);
    return;
  }
  for (const [codec, c] of Object.entries(result.codecs)) {
    if (c.status) {
      console.log(`${name.padEnd(20)} ${codec.padEnd(5)} ${c.status}: ${c.message}`);
      continue;
    }
    console.log(`${name.padEnd(20)} ${codec.padEnd(5)} ${String(c.bytes).padStart(8)} bytes  `
      + `write ${(c.write.medianUs / 1000).toFixed(1).padStart(8)} ms ${String(c.write.rowsPerSecond).padStart(8)} rows/s ${c.write.mbPerSecond.toFixed(2).padStart(6)} MB/s  `
      + `read ${(c.read.medianUs / 1000).toFixed(1).padStart(8)} ms ${String(c.read.rowsPerSecond).padStart(8)} rows/s ${c.read.mbPerSecond.toFixed(2).padStart(6)} MB/s  `
      + `pyarrow ${c.oracle.status}${c.oracle.status === "OK" ? "" : ` (${c.oracle.message})`}`);
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  mkdirSync(benchDir, {recursive: true});
  const report = {
    started: new Date().toISOString(),
    options: {rows: options.rows, runs: options.runs, seed: options.seed},
    host: {platform: process.platform, arch: process.arch, node: process.version},
    toolchains: {},
  };
  for (const name of options.toolchains) {
    report.toolchains[name] = name === "abaplint-transpiler" ? await runTranspiler(options) : runOsg(options);
  }
  writeFileSync(join(repoRoot, "results", "bench.json"), `${JSON.stringify(report, null, 2)}\n`);
  console.log(`rows ${options.rows}, runs ${options.runs}, seed ${options.seed}; times are the median of the runs`);
  for (const [name, result] of Object.entries(report.toolchains)) print(name, result);
  return Object.values(report.toolchains).every((t) => t.status === "OK") ? 0 : 1;
}

process.exitCode = await main();
