"""Schedule-only MCP server. It can reach data exclusively through REST."""

import os
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP


mcp = FastMCP("SkeChat Schedule Tools")
API_BASE_URL = os.getenv("SKECHAT_API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")


def _request(
    method: str,
    path: str,
    user_id: str,
    *,
    params: dict[str, Any] | None = None,
    json: dict[str, Any] | None = None,
) -> Any:
    with httpx.Client(base_url=API_BASE_URL, timeout=30) as client:
        response = client.request(
            method,
            path,
            headers={"X-User-Id": user_id},
            params=params,
            json=json,
        )
    if response.is_error:
        try:
            detail = response.json().get("detail", response.text)
        except ValueError:
            detail = response.text
        raise ValueError(f"REST API rejected the operation: {detail}")
    return response.json() if response.content else {"ok": True}


@mcp.tool()
def list_schedule(user_id: str, date: str | None = None) -> list[dict]:
    """Read only the authenticated user's active schedules."""
    params = {"date": date} if date else None
    return _request("GET", "/api/todos", user_id, params=params)


@mcp.tool()
def list_locations(user_id: str) -> list[dict]:
    """List active locations available to schedule creation."""
    return _request("GET", "/api/locations", user_id)


@mcp.tool()
def preview_create_schedule(
    user_id: str,
    conversation_id: str,
    eta: str,
    description: str,
    location_id: int | None = None,
    alarm_minutes_before: int = 10,
) -> dict:
    """Create a non-executing schedule creation preview."""
    return _request(
        "POST",
        "/api/schedule-operations/preview",
        user_id,
        json={
            "action": "create",
            "conversation_id": conversation_id,
            "changes": {
                "eta": eta,
                "description": description,
                "location_id": location_id,
                "alarm_minutes_before": alarm_minutes_before,
            },
        },
    )


@mcp.tool()
def preview_update_schedule(
    user_id: str,
    conversation_id: str,
    schedule_id: int,
    eta: str | None = None,
    description: str | None = None,
    alarm_id: str | None = None,
    alarm_minutes_before: int | None = None,
    location_id: int | None = None,
) -> dict:
    """Create a non-executing update preview. User confirmation is mandatory."""
    values = {
        "eta": eta,
        "description": description,
        "alarm_id": alarm_id,
        "alarm_minutes_before": alarm_minutes_before,
        "location_id": location_id,
    }
    changes = {key: value for key, value in values.items() if value is not None}
    if not changes:
        raise ValueError("At least one schedule change is required")
    return _request(
        "POST",
        "/api/schedule-operations/preview",
        user_id,
        json={
            "action": "update",
            "schedule_id": schedule_id,
            "conversation_id": conversation_id,
            "changes": changes,
        },
    )


@mcp.tool()
def preview_delete_schedule(
    user_id: str, conversation_id: str, schedule_id: int
) -> dict:
    """Create a soft-delete preview. User confirmation is mandatory."""
    return _request(
        "POST",
        "/api/schedule-operations/preview",
        user_id,
        json={
            "action": "delete",
            "schedule_id": schedule_id,
            "conversation_id": conversation_id,
        },
    )


@mcp.tool()
def confirm_schedule_operation(user_id: str, conversation_id: str) -> dict:
    """Execute the latest pending operation for this user and conversation."""
    return _request(
        "POST",
        "/api/schedule-operations/confirm",
        user_id,
        params={"conversation_id": conversation_id},
    )


@mcp.tool()
def cancel_schedule_operation(user_id: str, conversation_id: str) -> dict:
    """Cancel the latest pending operation for this user and conversation."""
    return _request(
        "POST",
        "/api/schedule-operations/cancel",
        user_id,
        params={"conversation_id": conversation_id},
    )


@mcp.tool()
def undo_schedule_operation(user_id: str, operation_id: str) -> dict:
    """Undo an executed operation only if the schedule has not changed since."""
    return _request(
        "POST",
        f"/api/schedule-operations/{operation_id}/undo",
        user_id,
    )


if __name__ == "__main__":
    mcp.run(transport="stdio")
