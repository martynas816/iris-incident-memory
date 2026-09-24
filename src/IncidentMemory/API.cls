Class IncidentMemory.API
{

ClassMethod Overview(incidentId As %Integer = 0) As %String [ Language = python ]
{
    import iris
    import json

    incidents = []

    rows = iris.sql.exec("""
        SELECT
            ID,
            SourceEventId,
            DetectedAt,
            Kind,
            Severity,
            Signature,
            Summary,
            EvidenceJSON
        FROM IncidentMemory.Incident
        ORDER BY DetectedAt DESC, ID DESC
    """)

    for row in rows:
        try:
            evidence = json.loads(str(row[7] or "{}"))
        except Exception:
            evidence = {}

        incidents.append({
            "id": int(row[0]),
            "source_event_id": int(row[1]),
            "detected_at": str(row[2]),
            "kind": str(row[3]),
            "severity": str(row[4]),
            "signature": str(row[5]),
            "summary": str(row[6]),
            "evidence": evidence
        })

    selected_id = int(incidentId or 0)

    if selected_id == 0 and incidents:
        selected_id = incidents[0]["id"]

    selected = None

    for incident in incidents:
        if incident["id"] == selected_id:
            selected = incident
            break

    timeline = json.loads(
        iris.cls("IncidentMemory.IncidentDetector").Timeline()
    )

    similar = {
        "query_incident_id": selected_id,
        "matches": []
    }

    if selected is not None:
        try:
            similar = json.loads(
                iris.cls(
                    "IncidentMemory.SimilarityIndex"
                ).FindSimilar(selected_id)
            )
        except Exception as e:
            similar = {
                "query_incident_id": selected_id,
                "matches": [],
                "error": str(e)
            }

    return json.dumps({
        "service": "IRIS Incident Memory",
        "incident_count": len(incidents),
        "selected_incident": selected,
        "similar_incidents": similar.get("matches", []),
        "incidents": incidents,
        "timeline": timeline
    }, indent=2)

}

}
