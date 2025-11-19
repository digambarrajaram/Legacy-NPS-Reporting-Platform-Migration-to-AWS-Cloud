# app/src/main.py
import os
import time
import logging
from typing import Optional

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import PlainTextResponse, JSONResponse
from pydantic import BaseModel
from pydantic_settings import BaseSettings
from pythonjsonlogger import jsonlogger

# Prometheus imports
from prometheus_client import (
    Counter,
    Gauge,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    multiprocess,
)

# -------- Logging (JSON) --------
logger = logging.getLogger("nps-app")
handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter("%(levelname)s %(name)s %(message)s"))
logger.setLevel(logging.INFO)
logger.addHandler(handler)

# -------- Config --------
class Settings(BaseSettings):
    app_name: str = "NPS Reporting Service"
    app_env: str = os.getenv("APP_ENV", "dev")
    version: str = os.getenv("APP_VERSION", "0.1.0")
    db_host: Optional[str] = None
    db_name: Optional[str] = None
    s3_bucket: Optional[str] = None

    model_config = {"env_prefix": "APP_", "extra": "ignore"}

settings = Settings()

# -------- Metrics (safe init, prevents duplicate registration) --------
# Use a module-level guard to avoid creating metrics twice in the same process.
if "METRICS_INITIALIZED" not in globals():
    try:
        REQ_COUNT = Counter("http_requests_total", "HTTP Requests", ["path", "method", "status"])
        REQ_LAT = Histogram(
            "http_request_duration_seconds",
            "HTTP request duration",
            buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5),
        )
        UP_GAUGE = Gauge("service_up", "Service up (1) / down (0)")
        # START_TIME can sometimes conflict in some setups — wrap in try/except
        try:
            START_TIME = Gauge("process_start_time_seconds", "Start time in unix timestamp")
            START_TIME.set_to_current_time()
        except ValueError:
            # metric already registered in this process; skip
            START_TIME = None

        # mark metrics as initialized to prevent double-registration
        METRICS_INITIALIZED = True
    except Exception as e:
        # If anything unexpected happens, log and continue (avoid crashing import)
        logger.exception({"msg": "metrics init failed", "error": str(e)})
        # ensure names exist to prevent NameError later
        REQ_COUNT = globals().get("REQ_COUNT", None)
        REQ_LAT = globals().get("REQ_LAT", None)
        UP_GAUGE = globals().get("UP_GAUGE", None)
        START_TIME = globals().get("START_TIME", None)

# set service up
try:
    if UP_GAUGE:
        UP_GAUGE.set(1)
except Exception:
    pass

# -------- App --------
app = FastAPI(title=settings.app_name, version=settings.version)

# Middleware to record latency and counts
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    try:
        if REQ_COUNT is not None:
            REQ_COUNT.labels(path=request.url.path, method=request.method, status=response.status_code).inc()
        if REQ_LAT is not None:
            REQ_LAT.observe(time.time() - start)
    except Exception as e:
        logger.exception({"msg": "metrics record failed", "error": str(e)})
    return response

# Health
@app.get("/health")
def health():
    return {"status": "ok", "env": settings.app_env, "version": settings.version}

# Metrics endpoint — supports multiprocess mode when PROMETHEUS_MULTIPROC_DIR is set
@app.get("/metrics")
def metrics():
    # If running in multiprocess mode (Gunicorn with multiple workers), the exporter files
    # are read by multiprocess.MultiProcessCollector into a CollectorRegistry.
    mp_dir = os.environ.get("PROMETHEUS_MULTIPROC_DIR")
    if mp_dir:
        try:
            registry = CollectorRegistry()
            multiprocess.MultiProcessCollector(registry)
            data = generate_latest(registry)
        except Exception as e:
            logger.exception({"msg": "failed to generate multiprocess metrics", "error": str(e)})
            # fallback to default generate_latest()
            data = generate_latest()
    else:
        # single-process default
        data = generate_latest()

    return PlainTextResponse(content=data.decode("utf-8"), media_type=CONTENT_TYPE_LATEST)

# Root
@app.get("/")
def root():
    return {"message": "NPS Reporting API", "version": settings.version}

# Example payload/endpoint you can extend later for reports
class ReportRequest(BaseModel):
    report_type: str
    from_date: str
    to_date: str
    limit: int = 100

@app.post("/reports/run")
def run_report(req: ReportRequest):
    if req.limit <= 0:
        raise HTTPException(400, "limit must be > 0")
    logger.info({"msg": "report_requested", "type": req.report_type, "from": req.from_date, "to": req.to_date, "limit": req.limit})
    return JSONResponse(
        {
            "status": "accepted",
            "report_type": req.report_type,
            "rows": min(req.limit, 1000),
            "storage": {"bucket": settings.s3_bucket, "prefix": f"reports/{req.report_type}/"},
        }
    )
