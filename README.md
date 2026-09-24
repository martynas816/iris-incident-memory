# IRIS Incident Memory

Incident investigation for InterSystems IRIS.

IRIS Incident Memory is a focused management portal that helps operators answer:

**What just broke, what happened around it, and have we seen something similar before?**

## Goal

The application will correlate operational evidence from InterSystems IRIS, including:

- system and application logs
- failed or abnormal scheduled tasks
- process and system activity
- CPU, memory and storage context

Historical incidents will be normalized with Embedded Python and stored in InterSystems IRIS. IRIS Vector Search will be used to retrieve similar past incidents.

The interface is evidence-first: similarity results link back to the actual events that produced them rather than presenting an unsupported AI answer.

## Community Idea

This project implements the InterSystems Community Opportunity:

**AI analysis of error logs**

https://ideas.intersystems.com/ideas/DPI-I-574

## Contest

Built for the 2026 InterSystems Programming Contest:

**Build Your Own Management Portal**

## Planned MVP

1. Incident timeline combining relevant IRIS management signals.
2. Error-signature normalization with Embedded Python.
3. Historical incident persistence in IRIS.
4. Similar-incident retrieval with IRIS Vector Search.
5. Clear evidence showing why two incidents are considered related.
6. Docker-based local deployment.
7. IPM/ZPM package deployment.

## Status

Development in progress.

Installation and demonstration instructions will be added before the contest submission is sent for approval.

## License

MIT
