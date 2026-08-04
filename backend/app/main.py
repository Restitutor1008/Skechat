import asyncio
from contextlib import asynccontextmanager
from contextlib import suppress

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .command_log_service import purge_expired_command_logs
from .config import get_settings
from .database import SessionLocal, init_database
from .mcp_client import start_mcp_client, stop_mcp_client
from .routes import router


COMMAND_LOG_CLEANUP_INTERVAL_SECONDS = 60 * 60


async def cleanup_expired_command_logs() -> None:
    while True:
        with SessionLocal() as db:
            purge_expired_command_logs(db)
        await asyncio.sleep(COMMAND_LOG_CLEANUP_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(_: FastAPI):
    if get_settings().run_db_migrations:
        init_database()
    await start_mcp_client()
    cleanup_task = asyncio.create_task(cleanup_expired_command_logs())
    try:
        yield
    finally:
        cleanup_task.cancel()
        with suppress(asyncio.CancelledError):
            await cleanup_task
        await stop_mcp_client()


app = FastAPI(title="SkeChat REST API", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(router)
