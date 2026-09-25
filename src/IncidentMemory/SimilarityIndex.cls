Class IncidentMemory.SimilarityIndex
{

ClassMethod Build() As %String [ Language = python ]
{
    import iris
    import json

    try:
        iris.sql.exec("""
            CREATE TABLE IncidentMemory.IncidentVector (
                IncidentId INTEGER NOT NULL,
                SourceEventId INTEGER,
                Label VARCHAR(300),
                IncidentText VARCHAR(4000),
                Embedding VECTOR(DOUBLE,128)
            )
        """)
    except Exception:
        iris.sql.exec("""
            DELETE FROM IncidentMemory.IncidentVector
        """)

    rows = iris.sql.exec("""
        SELECT
            ID,
            SourceEventId,
            Kind,
            Summary,
            EvidenceJSON
        FROM IncidentMemory.Incident
        ORDER BY ID
    """)

    indexed = 0

    for row in rows:
        incident_id = int(row[0])
        source_event_id = int(row[1])
        kind = str(row[2] or "")
        summary = str(row[3] or "")
        evidence_json = str(row[4] or "{}")

        try:
            evidence = json.loads(evidence_json)
        except Exception:
            evidence = {}

        task_name = str(evidence.get("name", ""))
        namespace = str(evidence.get("namespace", ""))
        result = str(evidence.get("result", ""))

        text = (
            kind + " "
            + task_name + " "
            + namespace + " "
            + result + " "
            + summary
        )

        vector = iris.cls(
            "IncidentMemory.TextVectorizer"
        ).Vectorize(text)

        iris.sql.exec("""
            INSERT INTO IncidentMemory.IncidentVector
                (IncidentId, SourceEventId, Label, IncidentText, Embedding)
            VALUES (?, ?, ?, ?, TO_VECTOR(?, DOUBLE, 128))
        """,
            incident_id,
            source_event_id,
            task_name,
            text,
            vector
        )

        indexed += 1

    try:
        iris.sql.exec("""
            CREATE INDEX IncidentVectorHNSW
            ON TABLE IncidentMemory.IncidentVector (Embedding)
            AS HNSW(Distance='Cosine')
        """)
    except Exception:
        pass

    return json.dumps({
        "indexed": indexed
    }, indent=2)
}


ClassMethod FindSimilar(incidentId As %Integer) As %String [ Language = python ]
{
    import iris
    import json

    rows = iris.sql.exec("""
        SELECT Label, IncidentText
        FROM IncidentMemory.IncidentVector
        WHERE IncidentId = ?
    """, incidentId)

    target = None

    for row in rows:
        target = {
            "label": str(row[0] or ""),
            "text": str(row[1] or "")
        }
        break

    if target is None:
        return json.dumps({
            "error": "Incident not found in vector index"
        }, indent=2)

    query_vector = iris.cls(
        "IncidentMemory.TextVectorizer"
    ).Vectorize(target["text"])

    rows = iris.sql.exec("""
        SELECT TOP 5
            IncidentId,
            SourceEventId,
            Label,
            IncidentText,
            VECTOR_COSINE(
                Embedding,
                TO_VECTOR(?, DOUBLE, 128)
            ) AS Score
        FROM IncidentMemory.IncidentVector
        WHERE IncidentId <> ?
        ORDER BY Score DESC
    """,
        query_vector,
        incidentId
    )

    matches = []

    for row in rows:
        matches.append({
            "incident_id": int(row[0]),
            "source_event_id": int(row[1]),
            "label": str(row[2]),
            "score": float(row[4]),
            "text": str(row[3])
        })

    return json.dumps({
        "query_incident_id": incidentId,
        "query_label": target["label"],
        "matches": matches
    }, indent=2)
}

}
