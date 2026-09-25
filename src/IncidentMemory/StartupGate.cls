Class IncidentMemory.StartupGate
{

ClassMethod WaitForExpiredTasks(timeoutSeconds As %Integer = 90) As %Integer [ Language = python ]
{
    import iris
    import time

    deadline = time.time() + int(timeoutSeconds)

    while time.time() < deadline:
        rows = iris.sql.exec("""
            SELECT TOP 1 ID
            FROM %SYS_Task.History
            WHERE Error LIKE 'Task Has Expired%'
            ORDER BY ID DESC
        """)

        for row in rows:
            return 1

        time.sleep(2)

    return 0
}

}
