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
def list_schedule(user_id: str, date: str) -> list[dict]:
    """Read the authenticated user's active schedules for one date."""
    return _request("GET", "/api/todos", user_id, params={"date": date})


@mcp.tool()
def list_locations(user_id: str) -> list[dict]:
    """List active locations available to schedule creation."""
    return _request("GET", "/api/locations", user_id)


@mcp.tool()
def preview_create_schedule(
    user_id: str,
    conversation_id: str,
    scheduled_date: str,
    eta: str | None = None,
    description: str = "",
    location_id: int | None = None,
    alarm_minutes_before: int = 10,
    pipeline_revision: int = 1,
) -> dict:
    """Create a non-executing schedule creation preview."""
    return _request(
        "POST",
        "/api/schedule-operations/preview",
        user_id,
        json={
            "action": "create",
            "conversation_id": conversation_id,
            "pipeline_revision": pipeline_revision,
            "allow_empty_description": True,
            "changes": {
                "eta": eta,
                "scheduled_date": scheduled_date,
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
    clear_time: bool = False,
    scheduled_date: str | None = None,
    description: str | None = None,
    alarm_id: str | None = None,
    alarm_minutes_before: int | None = None,
    location_id: int | None = None,
    clear_location: bool = False,
    pipeline_revision: int = 1,
) -> dict:
    """Create a non-executing update preview. User confirmation is mandatory."""
    values = {
        "eta": eta,
        "scheduled_date": scheduled_date,
        "description": description,
        "alarm_id": alarm_id,
        "alarm_minutes_before": alarm_minutes_before,
        "location_id": location_id,
    }
    changes = {key: value for key, value in values.items() if value is not None}
    if clear_time:
        changes["eta"] = None
    if clear_location:
        changes["location_id"] = None
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
            "pipeline_revision": pipeline_revision,
            "changes": changes,
        },
    )


@mcp.tool()
def preview_delete_schedule(
    user_id: str,
    conversation_id: str,
    schedule_id: int,
    pipeline_revision: int = 1,
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
            "pipeline_revision": pipeline_revision,
        },
    )


@mcp.tool()
def preview_batch_schedule(
    user_id: str,
    conversation_id: str,
    action: str,
    schedule_ids: list[int],
    changes: dict | None = None,
    select_all: bool = False,
    pipeline_revision: int = 1,
) -> dict:
    """Preview an atomic update/delete across user-selectable schedules."""
    body = {
        "action": action,
        "schedule_ids": schedule_ids,
        "conversation_id": conversation_id,
        "select_all": select_all,
        "pipeline_revision": pipeline_revision,
    }
    if changes:
        body["changes"] = changes
    return _request(
        "POST", "/api/schedule-operations/preview", user_id, json=body
    )


@mcp.tool()
def preview_mixed_schedule(
    user_id: str,
    conversation_id: str,
    items: list[dict],
    select_all: bool = True,
    pipeline_revision: int = 1,
) -> dict:
    """Preview one atomic pipeline containing mixed create/update/delete items."""
    return _request(
        "POST",
        "/api/schedule-operations/preview",
        user_id,
        json={
            "action": "mixed",
            "items": items,
            "conversation_id": conversation_id,
            "select_all": select_all,
            "pipeline_revision": pipeline_revision,
        },
    )


@mcp.tool()
def confirm_schedule_operation(
    user_id: str,
    conversation_id: str,
    expected_operation_id: str | None = None,
    expected_revision: int | None = None,
) -> dict:
    """Execute the latest pending operation for this user and conversation."""
    return _request(
        "POST",
        "/api/schedule-operations/confirm",
        user_id,
        params={
            "conversation_id": conversation_id,
            "expected_operation_id": expected_operation_id,
            "expected_revision": expected_revision,
        },
    )


@mcp.tool()
def cancel_schedule_operation(
    user_id: str,
    conversation_id: str,
    expected_operation_id: str | None = None,
) -> dict:
    """Cancel the latest pending operation for this user and conversation."""
    return _request(
        "POST",
        "/api/schedule-operations/cancel",
        user_id,
        params={
            "conversation_id": conversation_id,
            "expected_operation_id": expected_operation_id,
        },
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
