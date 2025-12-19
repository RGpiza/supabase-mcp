# Project Rules – Roblox Luau Codebase

## Project Architecture
This is a Roblox Luau project.

Structure:
- src/server → Server-side logic (RemoteFunctions, services, data handling)
- src/client → Client-side UI and controllers
- src/shared → Shared modules, constants, and types

## Authority & Networking Rules
- The server is authoritative
- Clients must not compensate for server errors
- RemoteFunctions must ALWAYS return a table
- RemoteEvents must never assume client state is valid
- Payload schemas are contractually locked

## RequestSync Contract
- RequestSync must never return nil
- RequestSync must always return a table
- All required payload keys must always exist
- Subsystem failures must degrade gracefully
- Partial failures must not break the sync loop

## Coding Standards
- Use Luau syntax and Roblox services
- Preserve existing architecture and patterns
- Do not invent new payload keys
- Avoid side effects inside RemoteFunction handlers
- Prefer defensive programming and schema validation

## AI Behavior Rules
- Analyze existing code before suggesting changes
- Reuse existing modules and services
- Do not refactor unrelated files
- Do not change client code unless explicitly instructed
- When rewriting, return the FULL file
