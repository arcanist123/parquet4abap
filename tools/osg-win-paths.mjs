// Preload for running open-steamgate tooling on native Windows.
//
// Parts of open-steamgate's tooling assume POSIX paths: they split and compare
// paths on "/", compare drive letters case-sensitively, and create directory
// symlinks, which Windows only allows with Developer Mode or elevation.
//
// - node:path returns forward slashes and an upper-case drive letter.
//   Windows accepts "D:/a/b" wherever it accepts "d:\a\b".
// - fs.symlinkSync(target, path, "dir") creates a junction instead, which
//   needs no extra rights and behaves the same for an absolute target.
//
// Upstream issues: oisee/open-steamgate#846 (paths split on "/"), #987 (drive
// letter case), #988 (directory symlinks).
//
// Load it with NODE_OPTIONS=--import=file:///<this file>, so child Node
// processes inherit it. Remove it once the tooling handles Windows itself.
import fs from "node:fs";
import path from "node:path";
import {syncBuiltinESMExports} from "node:module";

if (process.platform === "win32") {
  const tidy = (value) => typeof value === "string"
    ? value.replaceAll("\\", "/").replace(/^([a-z]):/, (_, drive) => `${drive.toUpperCase()}:`)
    : value;
  for (const name of ["join", "resolve", "normalize", "relative", "dirname"]) {
    const original = path[name];
    path[name] = (...args) => tidy(original(...args));
  }
  path.sep = "/";

  const symlinkSync = fs.symlinkSync;
  fs.symlinkSync = (target, link, type) =>
    symlinkSync(target, link, type === "dir" && path.isAbsolute(String(target)) ? "junction" : type);

  syncBuiltinESMExports();
  process.chdir(tidy(process.cwd()));
}
