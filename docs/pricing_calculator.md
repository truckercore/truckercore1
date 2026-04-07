# Pricing Calculator (Operators)

Purpose: Estimate monthly/annual cost for Premium Operator and Enterprise pilots, with multi‑location and prepay discounts. Paste into Google Sheets/Excel or use as a guide in your CPQ.

Inputs (user editable)
- Locations (N): number of locations enabled
- Band price per stop (USD): choose 199 (Local), 349 (Regional), 499 (National feature set). You can mix, but default to a single band for simplicity.
- Prepay term: Monthly | Quarterly | Annual
- Pilot months: default 3

Discount Rules
- Multi‑location (applied to subtotal before prepay):
  - 10–49 locations: 5%
  - 50–249 locations: 10%
  - 250+ locations: custom (use 15% placeholder; adjust in deal desk)
- Prepay:
  - Annual: 8% additional discount
  - Quarterly: 3% additional discount
  - Monthly: 0%

Calculator (sheet formulas)
- Base Subtotal (monthly): = N_locations * Band_Price
- Multi‑loc Discount % (monthly):
  =IF(N_locations>=250, 0.15, IF(N_locations>=50, 0.10, IF(N_locations>=10, 0.05, 0)))
- Subtotal after Multi‑loc: = Base_Subtotal * (1 - MultiLoc_Discount)
- Prepay Discount %: =IF(Term="Annual", 0.08, IF(Term="Quarterly", 0.03, 0))
- Net Monthly (if billed monthly):
  =IF(Term="Monthly", Subtotal_after_MultiLoc, Subtotal_after_MultiLoc)  // display; discount applied to prepay invoice
- Prepay Invoice Amount:
  - If Quarterly: = (Subtotal_after_MultiLoc * 3) * (1 - Prepay_Discount)
  - If Annual: = (Subtotal_after_MultiLoc * 12) * (1 - Prepay_Discount)
  - If Monthly: = Subtotal_after_MultiLoc (per month)
- Pilot (3 months) Cost:
  = IF(Term="Annual", (Prepay_Annual/12)*Pilot_Months, IF(Term="Quarterly", (Prepay_Quarterly/3)*Pilot_Months, Subtotal_after_MultiLoc*Pilot_Months))

Ready‑to‑Copy Table (CSV)
```
Locations,BandPricePerStop,Term,PilotMonths,BaseSubtotal,MultiLocDiscountPct,SubtotalAfterMulti,PrepayDiscountPct,PrepayInvoice,NetMonthly,PilotCost
20,349,Quarterly,3,=A2*B2,=IF(A2>=250,0.15,IF(A2>=50,0.10,IF(A2>=10,0.05,0))),=E2*(1-F2),=IF(C2="Annual",0.08,IF(C2="Quarterly",0.03,0)),=IF(C2="Annual",G2*12*(1-H2),IF(C2="Quarterly",G2*3*(1-H2),G2)),=G2,=IF(C2="Annual",I2/12*D2,IF(C2="Quarterly",I2/3*D2,G2*D2))
```

Example Scenarios
1) 12 locations, Regional band (349), Monthly prepay
- Base monthly: 12 * 349 = $4,188
- Multi‑loc 5% → $3,978.60
- Pilot (3 mo): ~$11,935.80

2) 60 locations, National feature set (499), Annual prepay
- Base monthly: 60 * 499 = $29,940
- Multi‑loc 10% → $26,946
- Annual prepay 8% → annual invoice $26,946*12*(1-0.08) = $297,950.88
- Pilot accounting (3 mo share): $297,950.88/12*3 ≈ $74,487.72

3) 200 locations, Local band (199), Quarterly prepay
- Base monthly: 200 * 199 = $39,800
- Multi‑loc 10% → $35,820
- Quarterly prepay 3% → invoice per quarter $35,820*3*(1-0.03) = $104,210.20
- Pilot (3 mo share): $104,210.20

Notes & Terms (attach to quote)
- Price protection: 12 months; renewal CPI cap 5%.
- Add/remove locations prorated to active month.
- Setup services (training/integration) optional; quoted separately.
- Enterprise add‑ons (SSO, white‑label, advanced analytics) require Enterprise plan; gated by plan claims.
- Taxes not included; currency USD unless specified.

Sales Checklist
- [ ] Confirm location count and band per region
- [ ] Apply multi‑loc and prepay options in calculator
- [ ] Include pilot cost and estimated ROI vs goals
- [ ] Export as PDF/Sheet and attach to proposal email
