// The environment open-steamgate's tooling runs in, shared by tools/run-osg.mjs
// and tools/run-bench.mjs: the Go toolchain and the open-steamgate checkout
// from tools/toolchains.lock.json, and on Windows the preload
// tools/osg-win-paths.mjs (see there for the upstream issues).
import {spawnSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {dirname, join, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

export const windows = process.platform === "win32";
// Forward slashes and an upper-case drive letter: the form open-steamgate's
// tooling handles on Windows (see tools/osg-win-paths.mjs).
export const tidy = (p) => windows ? p.replaceAll("\\", "/").replace(/^([a-z]):/, (_, d) => `${d.toUpperCase()}:`) : p;

export const repoRoot = tidy(resolve(dirname(fileURLToPath(import.meta.url)), ".."));
export const lock = JSON.parse(readFileSync(join(repoRoot, "tools", "toolchains.lock.json"), "utf8"))["open-steamgate"];
export const osgRoot = tidy(join(repoRoot, "tools", "open-steamgate"));
const shim = join(repoRoot, "tools", "osg-win-paths.mjs");

export function toolchainEnv() {
  const env = {...process.env, GOTOOLCHAIN: lock.go};
  // open-steamgate's tooling reads its transpiler pin from the environment.
  const result = spawnSync("node", ["tools/osd-lock.mjs", "github-env"], {cwd: osgRoot, encoding: "utf8"});
  if (result.status !== 0) throw new Error(`tools/osd-lock.mjs github-env exited ${result.status}\n${result.stderr}`);
  for (const line of result.stdout.split(/\r?\n/)) {
    const match = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (match) env[match[1]] = match[2];
  }
  if (windows) env.NODE_OPTIONS = [env.NODE_OPTIONS, `--import=${pathToFileURL(shim).href}`].filter(Boolean).join(" ");
  return env;
}
