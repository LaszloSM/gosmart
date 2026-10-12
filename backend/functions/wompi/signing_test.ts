import { assert, assertEquals } from '../ai-chat/test_assert.ts'
import { checkoutUrl, integrityPayload, integritySignature, sha256Hex, verifyEvent } from './signing.ts'

Deno.test('sha256 conocido', async () => {
  assertEquals(await sha256Hex('abc'),
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
})

Deno.test('la integridad concatena referencia, centavos, moneda y secreto', async () => {
  assertEquals(integrityPayload('gs_1', 2000000, 'COP', 's3cr3t'), 'gs_12000000COPs3cr3t')
  assertEquals(await integritySignature('gs_1', 2000000, 'COP', 's3cr3t'),
    await sha256Hex('gs_12000000COPs3cr3t'))
})

Deno.test('evento con checksum válido pasa; alterado no', async () => {
  const data = { transaction: { id: 'w-1', status: 'APPROVED', amount_in_cents: 2000000, reference: 'gs_1' } }
  const props = ['transaction.id', 'transaction.status', 'transaction.amount_in_cents']
  const ts = 1700000000
  const checksum = await sha256Hex(`w-1APPROVED2000000${ts}evsecret`)
  const ev = { event: 'transaction.updated', data, signature: { properties: props, checksum }, timestamp: ts }
  assert(await verifyEvent(ev, 'evsecret'))
  assert(!(await verifyEvent(ev, 'otro')))
  const forged = structuredClone(ev)
  forged.data.transaction.amount_in_cents = 99900000
  assert(!(await verifyEvent(forged, 'evsecret')))
  assert(!(await verifyEvent({ ...ev, signature: undefined }, 'evsecret')))
})

Deno.test('URL de checkout lleva la firma y el monto en centavos', () => {
  const u = new URL(checkoutUrl({ publicKey: 'pub_test_x', reference: 'gs_1', amountInCents: 2000000, signature: 'abc' }))
  assertEquals(u.origin, 'https://checkout.wompi.co')
  assertEquals(u.searchParams.get('amount-in-cents'), '2000000')
  assertEquals(u.searchParams.get('signature:integrity'), 'abc')
})
