Class IncidentMemory.Incident Extends %Persistent
{

Property SourceEventId As %Integer;

Property DetectedAt As %TimeStamp;

Property Kind As %String(MAXLEN = 64);

Property Severity As %String(MAXLEN = 16);

Property Signature As %String(MAXLEN = 256);

Property Summary As %String(MAXLEN = 1000);

Property EvidenceJSON As %String(MAXLEN = 12000);

Index SignatureIndex On Signature;

Index SourceEventIndex On SourceEventId [ Unique ];

}
