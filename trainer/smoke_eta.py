import os, requests, json, datetime as dt, uuid
CALLBACK_URL=os.environ["TRAINER_CALLBACK_URL"]
SECRET=os.environ["TRAINER_WEBHOOK_SECRET"]
ETA_ENDPOINT=os.environ.get("ETA_MODEL_ENDPOINT","https://example.com/model/eta/v1")

version = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")+"-"+str(uuid.uuid4())[:6]
payload={"job_id":"smoke","model_key":"eta","version":version,"artifact_url":ETA_ENDPOINT,"metrics":{"mae_min":12.3,"rmse_min":18.7,"n":50}}
r=requests.post(CALLBACK_URL,headers={"x-trainer-signature":SECRET,"content-type":"application/json"},data=json.dumps(payload))
r.raise_for_status()
print("seeded",version)
