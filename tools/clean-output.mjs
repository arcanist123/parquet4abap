// Removes the transpiler output folder so every run starts clean.
import { rmSync } from "node:fs";

rmSync(new URL("../output", import.meta.url), { recursive: true, force: true });
