#!/usr/bin/env node
// Runs abaplint on this repository with the CLI built from its Git repository,
// not the published npm package, so fixes on a fork apply before they are released.
//
//   node tools/run-lint.mjs [--local DIR [--build]] [--skip-setup] [-- ABAPLINT_ARGS...]
//
// Without --local, the abaplint commit comes from tools/toolchains.lock.json;
// the checkout and its build live in tools/abaplint, outside this repository.
// --local DIR uses an existing checkout instead (a fork or a branch with a fix)
// as it is; --build compiles it first. --skip-setup reuses tools/abaplint.
// Arguments after -- go to abaplint; without them it lints with abaplint.json.
//
// Exit code: the one abaplint returns, or 4 when setup failed.
import {spawnSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync} from "node:fs";
import {dirname, join, resolve} from "node:path";
import {fileURLToPath} from "node:url";

const windows = process.platform === "win32";
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const lock = JSON.parse(readFileSync(join(repoRoot, "tools", "toolchains.lock.json"), "utf8"))["abaplint"];
const checkoutDir = join(repoRoot, "tools", "abaplint");
// Built in this order: the CLI compiles against the core package next to it.
const packages = ["core", "cli"];

class SetupError extends Error {}

function parseArgs(argv) {
  const options = {local: undefined, build: false, skipSetup: false, passThrough: []};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--") {
      options.passThrough = argv.slice(i + 1);
      break;
    } else if (arg === "--help" || arg === "-h") {
      console.log(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 13).map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
      process.exit(0);
    } else if (arg === "--local") {
      if (!argv[i + 1]) throw new SetupError("--local needs a directory");
      options.local = resolve(argv[++i]);
    } else if (arg === "--build") options.build = true;
    else if (arg === "--skip-setup") options.skipSetup = true;
    else throw new SetupError(`unexpected argument: ${arg}`);
  }
  if (options.build && !options.local) throw new SetupError("--build only applies with --local");
  return options;
}

function run(command, args, {cwd, capture = false, allowFail = false} = {}) {
  // npm and npx are .cmd scripts on Windows and need a shell; their arguments
  // here are fixed strings, so they go as one command line.
  const viaShell = windows && (command === "npm" || command === "npx");
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
  console.error(`run-lint: ${message}`);
}

// A directory link that needs no extra rights on Windows.
function linkDirectory(target, path) {
  rmSync(path, {recursive: true, force: true});
  mkdirSync(dirname(path), {recursive: true});
  symlinkSync(target, path, windows ? "junction" : "dir");
}

// Returns true when the checkout moved to another commit and needs a build.
function prepareCheckout(dir) {
  const git = (...args) => run("git", args, {cwd: dir, capture: true}).stdout.trim();
  let fresh = false;
  if (!existsSync(join(dir, ".git"))) {
    log(`cloning ${lock.repo} into tools/abaplint`);
    run("git", ["clone", "--filter=blob:none", "--no-checkout", lock.repo, dir], {cwd: repoRoot});
    fresh = true;
  }
  // a clone without checkout shows every file as deleted
  if (!fresh && git("status", "--porcelain", "--untracked-files=no")) {
    throw new SetupError("tools/abaplint has local changes; commit, stash or discard them, or use --local for a working copy");
  }
  if (!fresh && git("remote", "get-url", "origin") !== lock.repo) {
    log(`switching origin to ${lock.repo}`);
    run("git", ["remote", "set-url", "origin", lock.repo], {cwd: dir});
  }
  if (!fresh && git("rev-parse", "HEAD") === lock.commit) return false;
  const known = run("git", ["cat-file", "-e", `${lock.commit}^{commit}`], {cwd: dir, capture: true, allowFail: true}).status === 0;
  if (!known) {
    log("fetching the locked commit");
    run("git", ["fetch", "--filter=blob:none", "origin", lock.commit], {cwd: dir});
  }
  log(`checking out ${lock.commit.slice(0, 8)}`);
  run("git", ["-c", "advice.detachedHead=false", "checkout", "--quiet", lock.commit], {cwd: dir});
  return true;
}

// The commit the current build was made from, so an unchanged checkout is not rebuilt.
const stampFile = (dir) => join(dir, "packages", "cli", "build", ".parquet4abap-commit");

function build(dir, {install}) {
  for (const name of packages) {
    const packageDir = join(dir, "packages", name);
    if (install) {
      log(`installing packages/${name} (npm ci)`);
      const ci = run("npm", ["ci", "--no-fund", "--no-audit"], {cwd: packageDir, capture: true, allowFail: true});
      if (ci.status !== 0) {
        // upstream sometimes bumps @abaplint/core in packages/cli/package.json
        // before its lock file; the core is linked from this checkout anyway
        log(`npm ci failed, installing packages/${name} without its lock file`);
        run("npm", ["install", "--no-package-lock", "--no-fund", "--no-audit"], {cwd: packageDir, capture: true});
      }
    }
    if (name === "cli") {
      // bundle the core from this checkout, not the published one
      linkDirectory(join(dir, "packages", "core"), join(packageDir, "node_modules", "@abaplint", "core"));
    }
    log(`compiling packages/${name}`);
    run("npm", ["run", "compile"], {cwd: packageDir, capture: true});
    if (name === "core") {
      // the typings the CLI compiles against, build/abaplint.d.ts, come from
      // api-extractor, which upstream runs as part of npm test
      log("writing the packages/core typings (api-extractor)");
      run("npx", ["api-extractor", "run", "--local"], {cwd: packageDir, capture: true});
    }
    if (name === "cli") {
      log("bundling packages/cli");
      run("npm", ["run", "webpack"], {cwd: packageDir, capture: true});
    }
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  let dir = checkoutDir;
  if (options.local) {
    dir = options.local;
    if (options.build) build(dir, {install: !existsSync(join(dir, "packages", "cli", "node_modules"))});
  } else if (!options.skipSetup) {
    const moved = prepareCheckout(dir);
    const commit = run("git", ["rev-parse", "HEAD"], {cwd: dir, capture: true}).stdout.trim();
    const built = existsSync(stampFile(dir)) && readFileSync(stampFile(dir), "utf8").trim() === commit;
    if (moved || !built) {
      build(dir, {install: true});
      writeFileSync(stampFile(dir), `${commit}\n`);
    }
  }
  const cli = join(dir, "packages", "cli", "abaplint");
  if (!existsSync(join(dir, "packages", "cli", "build", "cli.js"))) {
    throw new SetupError(`no abaplint build in ${dir}; run without --skip-setup, or with --local DIR --build`);
  }
  return run("node", [cli, ...options.passThrough], {cwd: repoRoot, allowFail: true}).status ?? 1;
}

try {
  process.exitCode = main();
} catch (e) {
  if (!(e instanceof SetupError)) throw e;
  log(e.message);
  process.exitCode = 4;
}
