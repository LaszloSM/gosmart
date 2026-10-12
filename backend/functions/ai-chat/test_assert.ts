// Aserciones mínimas sin depender de deno.land (bloqueado en algunos entornos).
export function assert(cond: unknown, msg = 'assertion failed'): asserts cond {
  if (!cond) throw new Error(msg)
}
export function assertEquals(a: unknown, b: unknown) {
  const sa = JSON.stringify(a), sb = JSON.stringify(b)
  if (sa !== sb) throw new Error(`esperado ${sb}, fue ${sa}`)
}
