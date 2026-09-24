Class IncidentMemory.ManagementSnapshot
{

ClassMethod Get() As %String [ Language = python ]
{
    import iris
    import json

    snapshot = {
        "system": {
            "state": int(iris.system.Monitor.State()),
            "alerts": int(iris.system.Monitor.Alerts())
        },
        "processes": [],
        "task_history": []
    }

    processes = iris.sql.exec("""
        SELECT TOP 5
            Pid,
            NameSpace,
            Routine,
            State,
            CPUTime,
            Username
        FROM %SYS.ProcessQuery
        ORDER BY CPUTime DESC
    """)

    for row in processes:
        snapshot["processes"].append({
            "pid": int(row[0]),
            "namespace": str(row[1] or ""),
            "routine": str(row[2] or ""),
            "state": str(row[3] or ""),
            "cpu_time": int(row[4] or 0),
            "username": str(row[5] or "")
        })

    tasks = iris.sql.exec("""
        SELECT TOP 10
            Name,
            NameSpace,
            Status,
            Error,
            LastStarted,
            LastFinished
        FROM %SYS_Task.History
        ORDER BY LogDate DESC, LogTime DESC
    """)

    for row in tasks:
        snapshot["task_history"].append({
            "name": str(row[0] or ""),
            "namespace": str(row[1] or ""),
            "status": str(row[2] or ""),
            "error": str(row[3] or ""),
            "last_started": str(row[4] or ""),
            "last_finished": str(row[5] or "")
        })

    return json.dumps(snapshot, indent=2)
}

}
