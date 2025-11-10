from fastapi import FastAPI
import os

app = FastAPI(title="ml-service")

@app.get("/health")
def health():
    return {"status": "ok", "env": os.environ.get("ENV", "dev")}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8080)
