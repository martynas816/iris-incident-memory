Class IncidentMemory.IncidentDetector
{

ClassMethod Ingest() As %String [ Language = python ]
{
    import iris
    import json
    from datetime import datetime, timedelta

    def event_time(log_date, log_time):
        if not log_date:
            return None
        seconds = int(log_time or 0)
        base = datetime.strptime(str(log_date), "%Y-%m-%d")
        return (base + timedelta(seconds=seconds)).strftime("%Y-%m-%d %H:%M:%S")

    processes = []

    process_rows = iris.sql.exec("""
        SELECT TOP 5
            Pid,
            NameSpace,
            Routine,
            State,
            CPUTime
        FROM %SYS.ProcessQuery
        ORDER BY CPUTime DESC
    """)

    for row in process_rows:
        processes.append({
            "pid": int(row[0]),
            "namespace": str(row[1] or ""),
            "routine": str(row[2] or ""),
            "state": str(row[3] or ""),
            "cpu_time": int(row[4] or 0)
        })

    system_context = {
        "monitor_state": int(iris.system.Monitor.State()),
        "monitor_alerts": int(iris.system.Monitor.Alerts()),
        "top_processes": processes
    }

    stats = {
        "new_incidents": 0,
        "new_changes": 0,
        "already_seen": 0
    }

    task_rows = iris.sql.exec("""
        SELECT TOP 100
            ID,
            Name,
            NameSpace,
            Error,
            ExecuteCode,
            DisplayErrorNumber,
            Username,
            DisplayLogDate,
            LogTime,
            DisplayStarted,
            DisplayFinished
        FROM %SYS_Task.History
        ORDER BY ID DESC
    """)

    for row in task_rows:
        source_id = int(row[0])
        name = str(row[1] or "")
        namespace = str(row[2] or "")
        result = str(row[3] or "")
        execute_code = str(row[4] or "")
        error_number = str(row[5] or "")
        username = str(row[6] or "")
        log_date = str(row[7] or "")
        log_time = str(row[8] or "")
        started = str(row[9] or "")
        finished = str(row[10] or "")

        is_expired = result.startswith("Task Has Expired")

        is_change = (
            execute_code == "TASKMGR"
            and (
                result.startswith("Create ")
                or name.startswith("TASKMGR ")
            )
        )

        is_failure = (
            not is_expired
            and not is_change
            and (
                bool(error_number)
                or (
                    result
                    and result != "Success"
                    and execute_code != "TASKMGR"
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

        occurred_at = event_time(log_date, log_time)

        evidence = {
            "source": "%SYS_Task.History",
            "source_event_id": source_id,
            "name": name,
            "namespace": namespace,
            "result": result,
            "execute_code": execute_code,
            "error_number": error_number,
            "username": username,
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
            summary = "Scheduled task '" + name + "' missed its expected execution window."
        else:
            kind = "task-failure"
            severity = "error"
            summary = "Scheduled task '" + name + "' reported: " + result

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
