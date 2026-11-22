#!/usr/bin/env node
// Runs the ABAP Unit tests in src/ on open-steamgate's Go target and writes the
// result to results/osg-go-unit.json. open-steamgate's JavaScript path is left
// out: the abaplint transpiler covers ABAP on JavaScript (tools/run-transpiler.mjs).
//
//   node tools/run-osg.mjs [--skip-setup] [--class NAME...]
//
// The open-steamgate commit, the Go toolchain and the local patches come from
// tools/toolchains.lock.json. The checkout lives in tools/open-steamgate and is
// not part of this repository.
//
// Tests listed under "open-steamgate-go" in tools/known-gaps.json fail as KNOWN
// and do not fail the run; a known gap that passes is reported as FIXED.
//
// Exit code: 0 when no test failed unexpectedly; otherwise 1 for a test failure,
// 2 for a test not compiled or an error, as open-steamgate's runner counts them
// (3 when it found no tests), or 4 when setup failed.
import {spawnSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync, writeFileSync} from "node:fs";
import {dirname, join, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

const windows = process.platform === "win32";
// Forward slashes and an upper-case drive letter: the form open-steamgate's
// tooling handles on Windows (see tools/osg-win-paths.mjs).
const tidy = (p) => windows ? p.replaceAll("\\", "/").replace(/^([a-z]):/, (_, d) => `${d.toUpperCase()}:`) : p;

const repoRoot = tidy(resolve(dirname(fileURLToPath(import.meta.url)), ".."));
const lock = JSON.parse(readFileSync(join(repoRoot, "tools", "toolchains.lock.json"), "utf8"))["open-steamgate"];
const osgRoot = tidy(join(repoRoot, "tools", "open-steamgate"));
const srcDir = tidy(join(repoRoot, "src"));
const resultsDir = join(repoRoot, "results");
const shim = join(repoRoot, "tools", "osg-win-paths.mjs");
const knownGaps = JSON.parse(readFileSync(join(repoRoot, "tools", "known-gaps.json"), "utf8"))["open-steamgate-go"] ?? {};

class SetupError extends Error {}

function parseArgs(argv) {
  const options = {skipSetup: false, classes: []};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 18).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
      process.exit(0);
    } else if (arg === "--skip-setup") options.skipSetup = true;
    else if (arg === "--class") {
      while (argv[i + 1] && !argv[i + 1].startsWith("--")) options.classes.push(argv[++i].toUpperCase());
      if (!options.classes.length) throw new SetupError("--class needs at least one name");
    } else throw new SetupError(`unexpected argument: ${arg}`);
  }
  return options;
}

function run(command, args, {cwd = osgRoot, env = process.env, capture = false, allowFail = false} = {}) {
  // npm is a .cmd script on Windows and needs a shell; its arguments here are
  // fixed strings, so they go as one command line.
  const viaShell = windows && command === "npm";
  const result = spawnSync(viaShell ? [command, ...args].join(" ") : command, viaShell ? [] : args, {
    cwd, env, encoding: "utf8", maxBuffer: 512 * 1024 * 1024,
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    shell: viaShell,
  });
  if (result.error) throw new SetupError(`${command}: ${result.error.message}`);
  if (result.status !== 0 && !allowFail) {
    throw new SetupError(`${command} ${args.join(" ")} exited ${result.status}${capture ? `\n${result.stderr}` : ""}`);
  }
  return result;
}

const git = (...args) => run("git", args, {capture: true}).stdout.trim();

function log(message) {
  console.error(`run-osg: ${message}`);
}

// Clone if missing, move to the locked commit, and apply the local patches.
// A checkout with changes other than those patches is left alone.
function prepareCheckout() {
  if (!existsSync(join(osgRoot, ".git"))) {
    log(`cloning ${lock.repo} into tools/open-steamgate`);
    run("git", ["clone", "--filter=blob:none", "--no-checkout", lock.repo, osgRoot], {cwd: repoRoot});
  }
  const patches = lock.patches.map((p) => join(repoRoot, p));
  const applied = (patch) => run("git", ["apply", "--reverse", "--check", patch], {capture: true, allowFail: true}).status === 0;

  const dirty = git("status", "--porcelain", "--untracked-files=no");
  if (dirty) {
    for (const patch of patches) if (applied(patch)) run("git", ["apply", "--reverse", patch]);
    if (git("status", "--porcelain", "--untracked-files=no")) {
      throw new SetupError("tools/open-steamgate has local changes other than the locked patches; commit, stash or discard them first");
    }
  }
  const head = git("rev-parse", "HEAD");
  if (head !== lock.commit) {
    const known = run("git", ["cat-file", "-e", `${lock.commit}^{commit}`], {capture: true, allowFail: true}).status === 0;
    if (!known) {
      log("fetching the locked commit");
      run("git", ["fetch", "--filter=blob:none", "origin", lock.commit]);
    }
    log(`checking out ${lock.commit.slice(0, 8)}`);
    run("git", ["-c", "advice.detachedHead=false", "checkout", "--quiet", lock.commit]);
  }
  for (const patch of patches) run("git", ["apply", patch]);
}

// npm ci only when the dependencies do not match the locked commit yet.
function installDependencies() {
  const stamp = join(osgRoot, "node_modules", ".parquet4abap-commit");
  if (existsSync(stamp) && readFileSync(stamp, "utf8").trim() === lock.commit) return;
  log("installing open-steamgate dependencies (npm ci)");
  run("npm", ["ci", "--no-fund", "--no-audit"]);
  writeFileSync(stamp, `${lock.commit}\n`);
}

function toolchainEnv() {
  const env = {...process.env, GOTOOLCHAIN: lock.go};
  // open-steamgate's tooling reads its transpiler pin from the environment.
  const lines = run("node", ["tools/osd-lock.mjs", "github-env"], {capture: true}).stdout.split(/\r?\n/);
  for (const line of lines) {
    const match = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (match) env[match[1]] = match[2];
  }
  if (windows) env.NODE_OPTIONS = [env.NODE_OPTIONS, `--import=${pathToFileURL(shim).href}`].filter(Boolean).join(" ");
  return env;
}

// Fresh clones on Windows are sometimes locked for a moment (indexer or
// antivirus) and the rename into .local/pins fails with EPERM; a retry clears it.
function syncLibraries(env) {
  for (let attempt = 1; ; attempt++) {
    const result = run("node", ["tools/osd-libs.mjs"], {env, capture: true, allowFail: true});
    if (result.status === 0) break;
    if (attempt === 5) throw new SetupError(`library sync failed:\n${result.stderr}`);
    log(`library sync failed (attempt ${attempt}), retrying`);
  }
  run("node", ["tools/osd-libs.mjs", "--check"], {env, capture: true});
}

function checkGo(env) {
  const result = run("go", ["version"], {env, capture: true, allowFail: true});
  if (result.status !== 0) throw new SetupError(`Go is required for the Go path (${lock.go}); install Go and retry`);
  return result.stdout.trim();
}

function runTests(env, classes) {
  const args = ["tools/osgo-unit.mjs", srcDir, "--json", ...(classes.length ? ["--class", ...classes] : [])];
  log("open-steamgate Go target: unit tests");
  const started = new Date();
  const child = run("node", args, {env, capture: true, allowFail: true});
  const durationMs = Date.now() - started.getTime();

  let result;
  try { result = JSON.parse(child.stdout.trim().split(/\r?\n/).at(-1)); }
  catch { result = {rows: [{source: "run-osg", status: "ERROR", message: child.stderr.trim() || `no JSON output (exit ${child.status})`}]}; }

  // known gaps: KNOWN while they fail, FIXED once they pass
  const rows = result.rows ?? [];
  for (const row of rows) {
    const gap = knownGaps[[row.class, row.testclass, row.method].join("/")];
    if (!gap) continue;
    row.gap = gap;
    if (row.status === "SUCCESS") row.status = "FIXED";
    else {
      row.osgStatus = row.status;
      row.status = "KNOWN";
    }
  }
  const unexpected = rows.filter((r) => !["SUCCESS", "KNOWN", "FIXED"].includes(r.status));
  const exitCode = rows.length === 0 ? child.status
    : unexpected.some((r) => r.status !== "FAILURE") ? 2
      : unexpected.length > 0 ? 1 : 0;
  result.totals = {...result.totals,
    known: rows.filter((r) => r.status === "KNOWN").length,
    fixed: rows.filter((r) => r.status === "FIXED").length,
    failure: rows.filter((r) => r.status === "FAILURE").length,
    not_compiled: rows.filter((r) => r.status === "NOT_COMPILED").length,
    error: rows.filter((r) => r.status === "ERROR").length};

  return {
    toolchain: "open-steamgate-go",
    exitCode,
    osgExitCode: child.status,
    started: started.toISOString(),
    durationMs,
    openSteamgate: {repo: lock.repo, commit: lock.commit, patches: lock.patches},
    host: {platform: process.platform, arch: process.arch, node: process.version, go: env.GOTOOLCHAIN},
    result,
  };
}

function summarize(report) {
  const totals = report.result.totals ?? {};
  const label = report.toolchain.padEnd(20);
  console.log(`${label} exit ${report.exitCode}  tests ${totals.tests ?? 0}  success ${totals.success ?? 0}  failure ${totals.failure ?? 0}  not_compiled ${totals.not_compiled ?? 0}  error ${totals.error ?? 0}  known ${totals.known ?? 0}  fixed ${totals.fixed ?? 0}  (${(report.durationMs / 1000).toFixed(1)} s)`);
  for (const row of report.result.rows ?? []) {
    if (row.status === "SUCCESS") continue;
    const where = [row.class, row.testclass, row.method].filter(Boolean).join("/") || "run";
    console.log(`  ${row.status} ${where}${row.gap ? ` (${row.gap})` : ""}: ${String(row.message ?? "").replace(/\s+/g, " ").slice(0, 300)}`);
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options.skipSetup) {
    prepareCheckout();
    installDependencies();
  }
  const env = toolchainEnv();
  if (!options.skipSetup) syncLibraries(env);
  checkGo(env);

  mkdirSync(resultsDir, {recursive: true});
  const report = runTests(env, options.classes);
  writeFileSync(join(resultsDir, "osg-go-unit.json"), `${JSON.stringify(report, null, 2)}\n`);
  summarize(report);
  return report.exitCode ?? 2;
}

try {
  process.exitCode = main();
} catch (error) {
  if (!(error instanceof SetupError)) throw error;
  log(error.message);
  process.exitCode = 4;
}
