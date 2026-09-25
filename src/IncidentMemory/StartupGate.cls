Class IncidentMemory.StartupGate
{

ClassMethod WaitForExpiredTasks(timeoutSeconds As %Integer = 90, username As %String = "", password As %String = "") As %Integer [ Language = python ]
{
    import iris
    import json
    import time

    deadline = time.time() + int(timeoutSeconds)

    while time.time() < deadline:
        try:
            raw = iris.cls("IncidentMemory.SysAdminClient").Get(
                "/task/history/?maxRows=100",
                username,
                password
            )

            rows = json.loads(raw).get("result", [])

            for row in rows:
                result = str(row.get("Result") or "")
                if result.startswith("Task Has Expired"):
                    return 1

        except Exception:
            pass

        time.sleep(2)

    return 0
}

}
