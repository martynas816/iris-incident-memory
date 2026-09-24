Class IncidentMemory.TimelineEvent Extends %Persistent
{

Property SourceEventId As %Integer;

Property OccurredAt As %TimeStamp;

Property EventType As %String(MAXLEN = 32);

Property Kind As %String(MAXLEN = 64);

Property Title As %String(MAXLEN = 500);

Property Detail As %String(MAXLEN = 2000);

Property EvidenceJSON As %String(MAXLEN = 12000);

Index SourceEventIndex On SourceEventId [ Unique ];

}
