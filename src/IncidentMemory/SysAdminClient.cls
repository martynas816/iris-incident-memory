Class IncidentMemory.SysAdminClient
{

ClassMethod Get(path As %String, username As %String, password As %String) As %String [ Language = python ]
{
    import base64
    import json
    import urllib.request

    url = "http://127.0.0.1:52773/api/admin/v1" + str(path)

    token = base64.b64encode(
        (str(username) + ":" + str(password)).encode("utf-8")
    ).decode("ascii")

    request = urllib.request.Request(
        url,
        headers={
            "Authorization": "Basic " + token,
            "Accept": "application/json"
        }
    )

    with urllib.request.urlopen(request, timeout=15) as response:
        payload = json.loads(response.read().decode("utf-8"))

    errors = payload.get("status", {}).get("errors", [])
    if errors:
        raise RuntimeError(json.dumps(errors))

    return json.dumps(payload)
}

}
