import json
import os
import sys
from pathlib import Path
from typing import Any

from mcp import ClientSession, StdioServerParameters, stdio_client

from .config import get_settings


async def call_mcp_tool(name: str, arguments: dict[str, Any]) -> Any:
    backend_dir = Path(__file__).resolve().parents[1]
    settings = get_settings()
    environment = dict(os.environ)
    environment["SKECHAT_API_BASE_URL"] = settings.internal_api_base_url
    server = StdioServerParameters(
        command=sys.executable,
        args=[str(backend_dir / "mcp_server.py")],
        cwd=str(backend_dir),
        env=environment,
    )
    async with stdio_client(server) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            result = await session.call_tool(name, arguments=arguments)
    if result.isError:
        message = " ".join(
            item.text for item in result.content if getattr(item, "type", None) == "text"
        )
        raise ValueError(message or "MCP tool execution failed")
    if result.structuredContent is not None:
        structured = result.structuredContent
        return structured.get("result", structured) if isinstance(structured, dict) else structured
    for item in result.content:
        if getattr(item, "type", None) == "text":
            try:
                return json.loads(item.text)
            except json.JSONDecodeError:
                return item.text
    return None
