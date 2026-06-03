# Panino Fabric Companion Prototype

This is the first local-only companion mod prototype for the Adaptive Performance
System. It is intentionally small:

- emits newline-delimited JSON to `127.0.0.1` only;
- includes the Panino `launchSessionId` and optional session token;
- reports frame-time P50/P95/P99, average FPS, stutter count, dimension,
  `worldLoaded`, and `shaderActive`;
- does not upload player identity, world seed, chat, server address, or file
  names;
- never changes game logic.

The Core endpoint consumes the same schema through
`POST /api/v1/performance/session/sample` and merges companion frame metrics
with process, memory, GC, crash, and latest.log telemetry. Without this mod,
Panino must keep recommendations at JVM/memory/launch-log confidence and must
not claim FPS improvement.
