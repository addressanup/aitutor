/** Exponential backoff with full jitter; resets after a stable window. */
export class Backoff {
  private attempt = 0;
  private readonly baseMs: number;
  private readonly maxMs: number;

  constructor(baseMs = 250, maxMs = 8_000) {
    this.baseMs = baseMs;
    this.maxMs = maxMs;
  }

  /** Next delay in ms (full jitter), advancing the attempt counter. */
  next(rng: () => number = Math.random): number {
    const ceil = Math.min(this.maxMs, this.baseMs * 2 ** this.attempt);
    this.attempt++;
    return Math.floor(rng() * ceil);
  }

  reset(): void {
    this.attempt = 0;
  }
}
