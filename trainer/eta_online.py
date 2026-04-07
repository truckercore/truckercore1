import os, json, uuid, datetime as dt
import numpy as np
import psycopg2, requests
from sklearn.linear_model import SGDRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

DB_URL = os.environ.get("SUPABASE_DB_URL", "")
CALLBACK_URL = os.environ.get("TRAINER_CALLBACK_URL", "")
CALLBACK_SECRET = os.environ.get("TRAINER_WEBHOOK_SECRET", "")
ETA_ENDPOINT = os.environ.get("ETA_MODEL_ENDPOINT", "")


def fetch_joined(minutes=1440):
    if not DB_URL:
        return []
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute(
        """
      select
        (inf.features->>'distance_km')::float8,
        (inf.features->>'avg_speed_hist')::float8,
        (inf.features->>'hour_of_day')::float8,
        (inf.features->>'day_of_week')::float8,
        (fb.actual->>'eta_min')::float8
      from ai_inference_events inf
      join ai_feedback_events fb using (correlation_id)
      where inf.model_key='eta' and inf.created_at >= now() - interval %s
    """,
        (f"{minutes} minutes",),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def train(rows):
    if not rows:
        return None
    X = np.array([r[:4] for r in rows])
    y = np.array([r[4] for r in rows])
    model = make_pipeline(StandardScaler(with_mean=True), SGDRegressor(loss="squared_error", penalty="l2"))
    model.fit(X, y)
    pred = model.predict(X)
    mae = float(np.mean(np.abs(pred - y)))
    rmse = float(np.sqrt(np.mean((pred - y) ** 2)))
    return {"mae_min": mae, "rmse_min": rmse, "n": int(len(y))}


def register(metrics):
    version = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ") + "-" + str(uuid.uuid4())[:8]
    r = requests.post(
        CALLBACK_URL,
        headers={"x-trainer-signature": CALLBACK_SECRET, "content-type": "application/json"},
        data=json.dumps(
            {
                "job_id": os.environ.get("JOB_ID", "ct"),
                "model_key": "eta",
                "version": version,
                "artifact_url": ETA_ENDPOINT,
                "metrics": metrics,
            }
        ),
        timeout=30,
    )
    r.raise_for_status()


if __name__ == "__main__":
    m = train(fetch_joined())
    if m:
        register(m)
