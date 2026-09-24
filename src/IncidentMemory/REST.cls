Class IncidentMemory.REST Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="Portal"/>
<Route Url="/health" Method="GET" Call="Health"/>
<Route Url="/api/overview" Method="GET" Call="Overview"/>
<Route Url="/api/overview/:incidentId" Method="GET" Call="OverviewById"/>
</Routes>
}

ClassMethod Portal() As %Status
{
    Set %response.ContentType = "text/html; charset=utf-8"

    Set stream=##class(%Stream.FileCharacter).%New()
    Set sc=stream.LinkToFile("/app/web/index.html")

    If 'sc {
        Set %response.Status="404 Not Found"
        Write "Portal file not found"
        Quit sc
    }

    While 'stream.AtEnd {
        Write stream.Read(32000)
    }

    Quit 1
}

ClassMethod Health() As %Status
{
    Set %response.ContentType = "application/json"
    Write "{""status"":""ok"",""service"":""IRIS Incident Memory""}"
    Quit 1
}

ClassMethod Overview() As %Status
{
    Set %response.ContentType = "application/json"
    Write ##class(IncidentMemory.API).Overview(0)
    Quit 1
}

ClassMethod OverviewById(incidentId As %Integer) As %Status
{
    Set %response.ContentType = "application/json"
    Write ##class(IncidentMemory.API).Overview(incidentId)
    Quit 1
}

}
