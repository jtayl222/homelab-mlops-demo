import pickle, os
from fastapi import FastAPI
import numpy as np
import uvicorn

model_path = os.getenv("MODEL_PATH", "/model/model.pkl")
with open(model_path, "rb") as f:
    model = pickle.load(f)

app = FastAPI()

@app.post("/predict")
def predict(payload: dict):
    data = np.array(payload["instances"])
    preds = model.predict(data).tolist()
    return {"predictions": preds}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
