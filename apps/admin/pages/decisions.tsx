import yaml from 'js-yaml';

export default async function Decisions() {
  const res = await fetch('/config/decisions.yml', { cache: 'no-store' });
  const text = await res.text();
  const cfg = yaml.load(text) as any;
  return (
    <main className="p-6">
      <h1 className="text-xl font-bold">Platform Decisions</h1>
      <pre className="bg-gray-50 p-4 rounded">{JSON.stringify(cfg, null, 2)}</pre>
    </main>
  );
}
