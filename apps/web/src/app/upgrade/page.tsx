export default function UpgradePage() {
  return (
    <div style={{ maxWidth: 960, margin: "0 auto", padding: 48 }}>
      <h1>Upgrade to TruckerCore Pro</h1>
      <p style={{ fontSize: 18, marginBottom: 32 }}>
        Unlock AI matching, unlimited exports, corridor analytics, and compliance automation.
      </p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: 24 }}>
        <Plan
          name="Free"
          price="$0/mo"
          features={["20 CSV exports/mo", "1 ROI report/mo", "3 boosted listings", "Basic analytics"]}
        />
        <Plan
          name="Pro"
          price="$149/mo"
          features={[
            "200 CSV exports/mo",
            "10 ROI reports/mo",
            "Unlimited boosted listings",
            "AI match suggestions",
            "Risk corridor heat maps",
            "E-sign & compliance automation",
            "12-month signed export retention",
          ]}
          cta="Start Free Trial"
        />
        <Plan
          name="Enterprise"
          price="$2,500/mo"
          features={[
            "Unlimited exports",
            "Unlimited ROI reports",
            "Real-time corridor refresh",
            "24-month audit retention",
            "SSO & custom SLA",
            "Dedicated CSM",
          ]}
          cta="Contact Sales"
        />
      </div>
    </div>
  );
}

const Plan: React.FC<{ name: string; price: string; features: string[]; cta?: string }> = ({ name, price, features, cta }) => (
  <div className="card" style={{ padding: 24 }}>
    <h2>{name}</h2>
    <div style={{ fontSize: 32, fontWeight: 700, marginBottom: 16 }}>{price}</div>
    <ul style={{ marginBottom: 24 }}>
      {features.map((f, i) => (
        <li key={i}>{f}</li>
      ))}
    </ul>
    {cta && <button onClick={() => alert("Checkout flow (Stripe)")}>{cta}</button>}
  </div>
);
