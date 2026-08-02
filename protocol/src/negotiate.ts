/**
 * Version negotiation: the core's hello carries [protocolMin, protocolMax]; the
 * responder picks the HIGHEST version it supports inside that inclusive range.
 * Anything outside the range — including a different major, which semver makes
 * out-of-range by ordering — yields null and error INCOMPATIBLE_PROTOCOL (-32001).
 */
export function parseSemver(v: string): [number, number, number] | null {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(v.trim());
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

export function compareSemver(a: string, b: string): number {
  const pa = parseSemver(a);
  const pb = parseSemver(b);
  if (!pa || !pb) throw new Error(`invalid semver: ${!pa ? a : b}`);
  for (let i = 0; i < 3; i++) {
    const d = (pa[i] as number) - (pb[i] as number);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

export function negotiate(min: string, max: string, supported: readonly string[]): string | null {
  if (!parseSemver(min) || !parseSemver(max)) return null;
  let best: string | null = null;
  for (const s of supported) {
    if (!parseSemver(s)) continue;
    if (compareSemver(s, min) < 0 || compareSemver(s, max) > 0) continue;
    if (best === null || compareSemver(s, best) > 0) best = s;
  }
  return best;
}
