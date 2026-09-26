Class IncidentMemory.IncidentDetector
{

ClassMethod Ingest(username As %String = "", password As %String = "") As %String [ Language = python ]
{
    import hashlib
    import iris
    import json

    def api(path):
        raw = iris.cls("IncidentMemory.SysAdminClient").Get(
            path,
            username,
            password
        )
        return json.loads(raw).get("result")

    def stable_event_id(item):
        identity = "|".join([
            str(item.get("TaskId") or ""),
            str(item.get("LogDatetime") or ""),
            str(item.get("Name") or ""),
            str(item.get("Result") or ""),
            str(item.get("Routine") or ""),
            str(item.get("Pid") or "")
        ])

        digest = hashlib.sha256(identity.encode("utf-8")).digest()

        return int.from_bytes(digest[:8], "big") & 0x7FFFFFFFFFFFFFFF

    process_rows = api("/processes?maxRows=100") or []

    process_rows = sorted(
        process_rows,
        key=lambda x: int(x.get("CPUTime") or 0),
        reverse=True
    )[:5]

    processes = []

    for row in process_rows:
        processes.append({
            "pid": int(row.get("Pid") or 0),
            "namespace": str(row.get("Nspace") or ""),
            "routine": str(row.get("Routine") or ""),
            "state": str(row.get("State") or ""),
            "cpu_time": int(row.get("CPUTime") or 0)
        })

    system_usage = api("/monitor/system-usage") or {}

    system_context = {
        "source": "InterSystems SysAdmin API",
        "task_history_endpoint": "/api/admin/v2/task/history",
        "process_endpoint": "/api/admin/v2/processes",
        "system_usage_endpoint": "/api/admin/v2/monitor/system-usage",
        "system_usage": system_usage,
        "top_processes": processes
    }

    stats = {
        "new_incidents": 0,
        "new_changes": 0,
        "already_seen": 0
    }

    task_rows = api("/task/history?maxRows=100") or []

    for item in task_rows:
        source_id = stable_event_id(item)

        task_id = int(item.get("TaskId") or 0)
        name = str(item.get("Name") or "")
        namespace = str(item.get("Namespace") or "")
        result = str(item.get("Result") or "")
        routine = str(item.get("Routine") or "")
        error_number = int(item.get("ErrNumber") or 0)
        username_value = str(item.get("Username") or "")
        started = str(item.get("LastStart") or "")
        finished = str(item.get("Completed") or "")
        occurred_at = str(
            item.get("LogDatetime")
            or item.get("Completed")
            or item.get("LastStart")
            or ""
        )

        is_expired = result.startswith("Task Has Expired")

        is_change = (
            username_value == "TASKMGR"
            and not is_expired
            and (
                result.startswith("Create ")
                or name.startswith("TASKMGR ")
            )
        )

        is_failure = (
            not is_expired
            and not is_change
            and (
                error_number != 0
                or (
                    result
                    and result != "Success"
                    and username_value != "TASKMGR"
                )
            )
        )

        if not (is_expired or is_change or is_failure):
            continue

        seen_rows = iris.sql.exec("""
            SELECT COUNT(*)
            FROM IncidentMemory.TimelineEvent
            WHERE SourceEventId = ?
        """, source_id)

        already_seen = False

        for seen_row in seen_rows:
            already_seen = int(seen_row[0]) > 0
            break

        if already_seen:
            stats["already_seen"] += 1
            continue

        evidence = {
            "source": "InterSystems SysAdmin API",
            "endpoint": "/api/admin/v2/task/history",
            "source_event_id": source_id,
            "task_id": task_id,
            "name": name,
            "namespace": namespace,
            "result": result,
            "execute_code": routine,
            "error_number": error_number,
            "username": username_value,
            "started": started,
            "finished": finished,
            "system_context": system_context
        }

        evidence_json = json.dumps(evidence)

        if is_change:
            iris.sql.exec("""
                INSERT INTO IncidentMemory.TimelineEvent
                    (SourceEventId, OccurredAt, EventType,
                     Kind, Title, Detail, EvidenceJSON)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
                source_id,
                occurred_at,
                "change",
                "task-configuration",
                name,
                result,
                evidence_json
            )

            stats["new_changes"] += 1
            continue

        if is_expired:
            kind = "task-expired"
            severity = "warning"
            summary = (
                "Scheduled task '" + name +
                "' missed its expected execution window."
            )
        else:
            kind = "task-failure"
            severity = "error"
            summary = (
                "Scheduled task '" + name +
                "' reported: " + result
            )

        signature = kind + ":" + name.lower().replace(" ", "-")

        iris.sql.exec("""
            INSERT INTO IncidentMemory.Incident
                (SourceEventId, DetectedAt, Kind, Severity,
                 Signature, Summary, EvidenceJSON)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
            source_id,
            occurred_at,
            kind,
            severity,
            signature,
            summary,
            evidence_json
        )

        iris.sql.exec("""
            INSERT INTO IncidentMemory.TimelineEvent
                (SourceEventId, OccurredAt, EventType,
                 Kind, Title, Detail, EvidenceJSON)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
            source_id,
            occurred_at,
            "anomaly",
            kind,
            name,
            result,
            evidence_json
        )

        stats["new_incidents"] += 1

    return json.dumps(stats, indent=2)
}


ClassMethod Timeline() As %String [ Language = python ]
{
    import iris
    import json

    result = []

    rows = iris.sql.exec("""
        SELECT TOP 50
            SourceEventId,
            OccurredAt,
            EventType,
            Kind,
            Title,
            Detail
        FROM IncidentMemory.TimelineEvent
        ORDER BY OccurredAt DESC, SourceEventId DESC
    """)

    for row in rows:
        result.append({
            "source_event_id": int(row[0]),
            "occurred_at": str(row[1]),
            "event_type": str(row[2]),
            "kind": str(row[3]),
            "title": str(row[4]),
            "detail": str(row[5])
        })

    return json.dumps(result, indent=2)
}

}
