#!/usr/bin/env node
// Runs the ABAP Unit tests in src/ on the abaplint transpiler, built from its
// Git repository, and writes the result to results/transpiler-unit.json.
//
//   node tools/run-transpiler.mjs [--local DIR [--build]] [--skip-setup] [--class NAME...]
//
// Without --local, the transpiler commit comes from tools/toolchains.lock.json;
// the checkout and its build live in tools/transpiler, outside this repository.
// --local DIR uses an existing checkout instead (a fork or a branch with a fix)
// as it is; --build compiles it first. --skip-setup reuses tools/transpiler.
//
// Tests listed in tools/known-gaps.json fail as KNOWN and do not fail the run;
// a known gap that passes is reported as FIXED.
//
// Exit code: 0 when no test failed unexpectedly, 1 on unexpected failures,
// 2 when transpiling failed, 4 when setup failed.
import {spawnSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync} from "node:fs";
import {dirname, join, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

const windows = process.platform === "win32";
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const lock = JSON.parse(readFileSync(join(repoRoot, "tools", "toolchains.lock.json"), "utf8"))["abaplint-transpiler"];
const knownGaps = JSON.parse(readFileSync(join(repoRoot, "tools", "known-gaps.json"), "utf8"))["abaplint-transpiler"] ?? {};
const outputDir = join(repoRoot, "output");
const resultsDir = join(repoRoot, "results");
// Built in this order: the CLI bundles the transpiler package next to it.
const packages = ["runtime", "transpiler", "cli"];

class SetupError extends Error {}

function parseArgs(argv) {
  const options = {local: undefined, build: false, skipSetup: false, classes: []};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 17).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
      process.exit(0);
    } else if (arg === "--local") {
      if (!argv[i + 1]) throw new SetupError("--local needs a directory");
      options.local = resolve(argv[++i]);
    } else if (arg === "--build") options.build = true;
    else if (arg === "--skip-setup") options.skipSetup = true;
    else if (arg === "--class") {
      while (argv[i + 1] && !argv[i + 1].startsWith("--")) options.classes.push(argv[++i].toUpperCase());
      if (!options.classes.length) throw new SetupError("--class needs at least one name");
    } else throw new SetupError(`unexpected argument: ${arg}`);
  }
  if (options.build && !options.local) throw new SetupError("--build only applies with --local");
  return options;
}

function run(command, args, {cwd, capture = false, allowFail = false} = {}) {
  // npm is a .cmd script on Windows and needs a shell; its arguments here are
  // fixed strings, so they go as one command line.
  const viaShell = windows && command === "npm";
  const result = spawnSync(viaShell ? [command, ...args].join(" ") : command, viaShell ? [] : args, {
    cwd, encoding: "utf8", maxBuffer: 512 * 1024 * 1024,
    stdio: capture ? ["ignore", "pipe", "pipe"] : ["ignore", "inherit", "inherit"],
    shell: viaShell,
  });
  if (result.error) throw new SetupError(`${command}: ${result.error.message}`);
  if (result.status !== 0 && !allowFail) {
    throw new SetupError(`${command} ${args.join(" ")} in ${cwd} exited ${result.status}${capture ? `\n${result.stderr}` : ""}`);
  }
  return result;
}

function log(message) {
  console.error(`run-transpiler: ${message}`);
}

// A directory link that needs no extra rights on Windows.
function linkDirectory(target, path) {
  rmSync(path, {recursive: true, force: true});
  mkdirSync(dirname(path), {recursive: true});
  symlinkSync(target, path, windows ? "junction" : "dir");
}

function prepareCheckout(dir) {
  const git = (...args) => run("git", args, {cwd: dir, capture: true}).stdout.trim();
  let fresh = false;
  if (!existsSync(join(dir, ".git"))) {
    log(`cloning ${lock.repo} into tools/transpiler`);
    run("git", ["clone", "--filter=blob:none", "--no-checkout", lock.repo, dir], {cwd: repoRoot});
    fresh = true;
  }
  // a clone without checkout shows every file as deleted
  if (!fresh && git("status", "--porcelain", "--untracked-files=no")) {
    throw new SetupError("tools/transpiler has local changes; commit, stash or discard them, or use --local for a working copy");
  }
  // the lock may move to another repository, e.g. a fork with fixes not merged yet
  if (!fresh && git("remote", "get-url", "origin") !== lock.repo) {
    log(`switching origin to ${lock.repo}`);
    run("git", ["remote", "set-url", "origin", lock.repo], {cwd: dir});
  }
  if (fresh || git("rev-parse", "HEAD") !== lock.commit) {
    const known = run("git", ["cat-file", "-e", `${lock.commit}^{commit}`], {cwd: dir, capture: true, allowFail: true}).status === 0;
    if (!known) {
      log("fetching the locked commit");
      run("git", ["fetch", "--filter=blob:none", "origin", lock.commit], {cwd: dir});
    }
    log(`checking out ${lock.commit.slice(0, 8)}`);
    run("git", ["-c", "advice.detachedHead=false", "checkout", "--quiet", lock.commit], {cwd: dir});
  }
}

function build(dir, {install}) {
  if (install) {
    // the packages compile against type definitions from the top-level
    // devDependencies; its own install script would set up every package
    log("installing the top level (npm ci --ignore-scripts)");
    run("npm", ["ci", "--ignore-scripts", "--no-fund", "--no-audit"], {cwd: dir, capture: true});
  }
  for (const name of packages) {
    const packageDir = join(dir, "packages", name);
    if (install) {
      log(`installing packages/${name} (npm ci)`);
      run("npm", ["ci", "--no-fund", "--no-audit"], {cwd: packageDir, capture: true});
    }
    if (name === "cli") {
      // bundle the transpiler from this checkout, not the published one
      linkDirectory(join(dir, "packages", "transpiler"), join(packageDir, "node_modules", "@abaplint", "transpiler"));
    }
    log(`compiling packages/${name}`);
    run("npm", ["run", "compile"], {cwd: packageDir, capture: true});
  }
}

function describe(dir) {
  const git = (...args) => run("git", args, {cwd: dir, capture: true, allowFail: true}).stdout.trim();
  return {
    dir,
    commit: git("rev-parse", "HEAD"),
    branch: git("rev-parse", "--abbrev-ref", "HEAD"),
    dirty: git("status", "--porcelain", "--untracked-files=no") !== "",
    version: JSON.parse(readFileSync(join(dir, "packages", "cli", "package.json"), "utf8")).version,
  };
}

function transpile(dir) {
  rmSync(outputDir, {recursive: true, force: true});
  log("transpiling src/");
  const result = run("node", [join(dir, "packages", "cli", "abap_transpile"), "abap_transpile.json"], {cwd: repoRoot, capture: true, allowFail: true});
  if (result.status !== 0) return result.stderr.trim() || result.stdout.trim() || `exit ${result.status}`;
  // the transpiled code imports @abaplint/runtime: take it from the same checkout
  linkDirectory(join(dir, "packages", "runtime"), join(outputDir, "node_modules", "@abaplint", "runtime"));
  return undefined;
}

// The test list the transpiler generates into output/index.mjs.
function testData() {
  const index = readFileSync(join(outputDir, "index.mjs"), "utf8");
  const match = /function getData\(\) \{[\s\S]*?\n {2}return ret;\n\}/.exec(index);
  if (!match) throw new SetupError("no test list found in output/index.mjs; the transpiler's runner format may have changed");
  return new Function(`${match[0]}\nreturn getData();`)();
}

function messageOf(error) {
  const text = (value) => value?.get?.() ?? value?.value ?? value;
  const parts = [text(error?.msg) || error?.message || String(error)];
  if (error?.actual !== undefined) parts.push(`act=${text(error.actual)}`, `exp=${text(error.expected)}`);
  return parts.filter((p) => p !== undefined && p !== "").join(" | ").replace(/\s+/g, " ");
}

async function runTests(classes) {
  await import(pathToFileURL(join(outputDir, "init.mjs")).href);
  const rows = [];
  for (const entry of testData()) {
    if (classes.length && !classes.includes(entry.objectName)) continue;
    const module = await import(pathToFileURL(join(outputDir, entry.filename)).href);
    const localClass = module[entry.localClass];
    if (localClass.class_setup) await localClass.class_setup();
    for (const method of entry.methods) {
      const key = `${entry.objectName}/${entry.localClass.toUpperCase()}/${method.name.toUpperCase()}`;
      const row = {class: entry.objectName, testclass: entry.localClass.toUpperCase(), method: method.name.toUpperCase()};
      if (method.skip) {
        rows.push({...row, status: "SKIPPED"});
        continue;
      }
      let error;
      try {
        const test = await (new localClass()).constructor_();
        const self = test.FRIENDS_ACCESS_INSTANCE;
        if (self.setup) await self.setup();
        try { await self[method.name](); } finally { if (self.teardown) await self.teardown(); }
      } catch (e) { error = e; }
      const gap = knownGaps[key];
      if (!error) rows.push({...row, status: gap ? "FIXED" : "SUCCESS", ...(gap ? {gap} : {})});
      else rows.push({...row, status: gap ? "KNOWN" : "FAILURE", message: messageOf(error), ...(gap ? {gap} : {})});
    }
    if (localClass.class_teardown) await localClass.class_teardown();
  }
  return rows;
}

function totals(rows) {
  const count = (status) => rows.filter((r) => r.status === status).length;
  return {tests: rows.length, success: count("SUCCESS"), failure: count("FAILURE"), known: count("KNOWN"), fixed: count("FIXED"), skipped: count("SKIPPED")};
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const dir = options.local ?? join(repoRoot, "tools", "transpiler");
  if (options.local) {
    if (!existsSync(join(dir, "packages", "cli"))) throw new SetupError(`${dir} is not a transpiler checkout`);
    if (options.build) build(dir, {install: false});
  } else if (!options.skipSetup) {
    prepareCheckout(dir);
    const stamp = join(dir, ".parquet4abap-build");
    if (!existsSync(stamp) || readFileSync(stamp, "utf8").trim() !== lock.commit) {
      build(dir, {install: true});
      writeFileSync(stamp, `${lock.commit}\n`);
    }
  }
  if (!existsSync(join(dir, "packages", "cli", "build", "bundle.js"))) throw new SetupError(`${dir} is not built yet`);

  const started = new Date();
  const transpileError = transpile(dir);
  const rows = transpileError
    ? [{source: "run-transpiler", status: "ERROR", message: transpileError}]
    : await runTests(options.classes);
  const report = {
    toolchain: "abaplint-transpiler",
    exitCode: transpileError ? 2 : rows.some((r) => r.status === "FAILURE") ? 1 : 0,
    started: started.toISOString(),
    durationMs: Date.now() - started.getTime(),
    transpiler: {repo: lock.repo, locked: lock.commit, ...describe(dir)},
    host: {platform: process.platform, arch: process.arch, node: process.version},
    result: {totals: totals(rows), rows},
  };

  mkdirSync(resultsDir, {recursive: true});
  writeFileSync(join(resultsDir, "transpiler-unit.json"), `${JSON.stringify(report, null, 2)}\n`);

  const t = report.result.totals;
  console.log(`abaplint-transpiler  exit ${report.exitCode}  tests ${t.tests}  success ${t.success}  failure ${t.failure}  known ${t.known}  fixed ${t.fixed}  (${(report.durationMs / 1000).toFixed(1)} s, ${report.transpiler.commit.slice(0, 8)}${options.local ? ` ${report.transpiler.branch}` : ""})`);
  for (const row of rows) {
    if (row.status === "SUCCESS" || row.status === "SKIPPED") continue;
    const where = [row.class, row.testclass, row.method].filter(Boolean).join("/") || "run";
    console.log(`  ${row.status} ${where}${row.gap ? ` (${row.gap})` : ""}${row.message ? `: ${row.message.slice(0, 300)}` : ""}`);
  }
  return report.exitCode;
}

try {
  process.exitCode = await main();
} catch (error) {
  if (!(error instanceof SetupError)) throw error;
  log(error.message);
  process.exitCode = 4;
}
