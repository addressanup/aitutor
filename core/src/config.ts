import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { DEFAULT_IPC_PORT, IPC_PATH } from "@aitutor/protocol";
import { z } from "zod";

/**
 * Config resolution, local-first. Env wins; otherwise the shell's handoff file.
 * Future home for persistent config + learner.db: ~/Library/Application Support/aitutor/
 * (scaffold keeps the dev db at core/.data/learner.db).
 */
const IpcHandoff = z.object({
  port: z.number(),
  token: z.string(),
  pid: z.number().optional(),
  protocolMin: z.string().optional(),
  protocolMax: z.string().optional(),
});

const HANDOFF_PATH = join(homedir(), "Library", "Application Support", "TutorShell", "ipc.json");

export interface CoreConfig {
  ipcUrl: string;
  ipcToken: string;
  logLevel: string;
  source: "env" | "handoff";
}

export function loadConfig(): CoreConfig {
  const logLevel = process.env.LOG_LEVEL ?? "info";
  const envUrl = process.env.AITUTOR_IPC_URL;
  const envToken = process.env.AITUTOR_IPC_TOKEN;
  if (envUrl && envToken) {
    return { ipcUrl: envUrl, ipcToken: envToken, logLevel, source: "env" };
  }

  try {
    const handoff = IpcHandoff.parse(JSON.parse(readFileSync(HANDOFF_PATH, "utf8")));
    return {
      ipcUrl: `ws://127.0.0.1:${handoff.port}${IPC_PATH}`,
      ipcToken: handoff.token,
      logLevel,
      source: "handoff",
    };
  } catch {
    // Fall through to a sane dev default so `make core-dev` works against fake-shell.
    return {
      ipcUrl: `ws://127.0.0.1:${DEFAULT_IPC_PORT}${IPC_PATH}`,
      ipcToken: envToken ?? "dev-token",
      logLevel,
      source: "env",
    };
  }
}
