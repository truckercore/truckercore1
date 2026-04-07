const { reconcile } = await import('../scripts/recon/reconcile_billing.mjs');

describe('billing reconciliation', () => {
  test('no drift', async () => {
    const rows = [ { org_id:'o1', entitled: 5, provisioned: 5 } ];
    const res = await reconcile(rows);
    expect(res.driftCount).toBe(0);
    expect(res.drifts).toHaveLength(0);
  });

  test('single drift', async () => {
    const rows = [ { org_id:'o1', entitled: 5, provisioned: 6 } ];
    const res = await reconcile(rows);
    expect(res.driftCount).toBe(1);
    expect(res.drifts[0]).toMatchObject({ org_id: 'o1', delta: 1 });
  });

  test('multiple drift', async () => {
    const rows = [ { org_id:'o1', entitled: 1, provisioned: 3 }, { org_id:'o2', entitled: 0, provisioned: 1 } ];
    const res = await reconcile(rows);
    expect(res.driftCount).toBe(2);
    expect(res.drifts.map(d=>d.org_id).sort()).toEqual(['o1','o2']);
  });
});
