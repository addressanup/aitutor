import { pino } from "pino";

export function makeLogger(level: string) {
  const usepretty = process.stdout.isTTY;
  return pino({
    level,
    ...(usepretty
      ? {
          transport: {
            target: "pino-pretty",
            options: { colorize: true, translateTime: "HH:MM:ss.l" },
          },
        }
      : {}),
  });
}

export type Logger = ReturnType<typeof makeLogger>;
