Class IncidentMemory.TextVectorizer
{

ClassMethod Vectorize(text As %String) As %String [ Language = python ]
{
    import hashlib
    import math
    import re

    dimensions = 128
    vector = [0.0] * dimensions

    tokens = re.findall(r"[a-z0-9]+", str(text).lower())

    features = list(tokens)

    for i in range(len(tokens) - 1):
        features.append(tokens[i] + "_" + tokens[i + 1])

    for feature in features:
        digest = hashlib.sha256(feature.encode("utf-8")).digest()

        index = int.from_bytes(digest[:4], "big") % dimensions
        sign = 1.0 if digest[4] % 2 == 0 else -1.0

        vector[index] += sign

    norm = math.sqrt(sum(value * value for value in vector))

    if norm > 0:
        vector = [value / norm for value in vector]

    return ",".join(str(value) for value in vector)
}

ClassMethod Test() As %String [ Language = python ]
{
    import iris
    import json

    texts = {
        "query": "Purge Journal task expired after restart",
        "related": "Journal purge task missed its execution window",
        "different": "User changed profile display name"
    }

    vectors = {}

    for key, value in texts.items():
        vectors[key] = iris.cls("IncidentMemory.TextVectorizer").Vectorize(value)

    try:
        iris.sql.exec("DROP TABLE IncidentMemory.TextVectorProbe")
    except Exception:
        pass

    iris.sql.exec("""
        CREATE TABLE IncidentMemory.TextVectorProbe (
            Label VARCHAR(80),
            Embedding VECTOR(DOUBLE,128)
        )
    """)

    iris.sql.exec("""
        INSERT INTO IncidentMemory.TextVectorProbe
            (Label, Embedding)
        VALUES (?, TO_VECTOR(?, DOUBLE, 128))
    """, "related", vectors["related"])

    iris.sql.exec("""
        INSERT INTO IncidentMemory.TextVectorProbe
            (Label, Embedding)
        VALUES (?, TO_VECTOR(?, DOUBLE, 128))
    """, "different", vectors["different"])

    iris.sql.exec("""
        CREATE INDEX TextVectorProbeHNSW
        ON TABLE IncidentMemory.TextVectorProbe (Embedding)
        AS HNSW(Distance='Cosine')
    """)

    rows = iris.sql.exec("""
        SELECT
            Label,
            VECTOR_COSINE(
                Embedding,
                TO_VECTOR(?, DOUBLE, 128)
            ) AS Score
        FROM IncidentMemory.TextVectorProbe
        ORDER BY Score DESC
    """, vectors["query"])

    result = []

    for row in rows:
        result.append({
            "label": str(row[0]),
            "score": float(row[1])
        })

    return json.dumps(result, indent=2)
}

}
