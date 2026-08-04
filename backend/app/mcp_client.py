import asyncio
from contextlib import AsyncExitStack
import json
import os
import sys
from pathlib import Path
from typing import Any

from mcp import ClientSession, StdioServerParameters, stdio_client

from .config import get_settings


class MCPClientManager:
    """Own one stdio MCP process/session for the FastAPI process lifetime."""

    def __init__(self) -> None:
        self._stack: AsyncExitStack | None = None
        self._session: ClientSession | None = None
        self._start_lock = asyncio.Lock()
        self._call_lock = asyncio.Lock()

    def _server_parameters(self) -> StdioServerParameters:
        backend_dir = Path(__file__).resolve().parents[1]
        settings = get_settings()
        environment = dict(os.environ)
        environment["SKECHAT_API_BASE_URL"] = settings.internal_api_base_url
        return StdioServerParameters(
            command=sys.executable,
            args=[str(backend_dir / "mcp_server.py")],
            cwd=str(backend_dir),
            env=environment,
        )

    async def start(self) -> None:
        async with self._start_lock:
            if self._session is not None:
                return
            stack = AsyncExitStack()
            try:
                read_stream, write_stream = await stack.enter_async_context(
                    stdio_client(self._server_parameters())
                )
                session = await stack.enter_async_context(
                    ClientSession(read_stream, write_stream)
                )
                await session.initialize()
            except BaseException:
                await stack.aclose()
                raise
            self._stack = stack
            self._session = session

    async def stop(self) -> None:
        async with self._call_lock:
            await self._close_session()

    async def _close_session(self) -> None:
        async with self._start_lock:
            stack = self._stack
            self._stack = None
            self._session = None
            if stack is not None:
                await stack.aclose()

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Any:
        # A single stdio session is serialized so concurrent HTTP requests cannot
        # interleave MCP messages. A broken session is closed and recreated by the
        # next request; writes are never retried automatically.
        async with self._call_lock:
            await self.start()
            session = self._session
            assert session is not None
            try:
                result = await session.call_tool(name, arguments=arguments)
            except BaseException:
                await self._close_session()
                raise
        if result.isError:
            message = " ".join(
                item.text
                for item in result.content
                if getattr(item, "type", None) == "text"
            )
            raise ValueError(message or "MCP tool execution failed")
        if result.structuredContent is not None:
            structured = result.structuredContent
            return (
                structured.get("result", structured)
                if isinstance(structured, dict)
                else structured
            )
        for item in result.content:
            if getattr(item, "type", None) == "text":
                try:
                    return json.loads(item.text)
                except json.JSONDecodeError:
                    return item.text
        return None


_manager = MCPClientManager()


async def start_mcp_client() -> None:
    await _manager.start()


async def stop_mcp_client() -> None:
    await _manager.stop()


async def call_mcp_tool(name: str, arguments: dict[str, Any]) -> Any:
    return await _manager.call_tool(name, arguments)
