---
active: true
iteration: 1
max_iterations: 0
completion_promise: null
started_at: "2026-02-13T02:43:38Z"
---

Perform a full project evolution for this app while preserving my existing UI.

1. ANALYZE & AUDIT:
   - Index all Swift/SwiftUI files. 
   - Identify hardcoded API keys, sensitive endpoints, and logic bugs.
   - Respect my UI: Do NOT change layouts or styles unless fixing a visual bug.

2. SHIELD & SECURE:
   - Use the Google Cloud MCP to initialize a Firebase environment for this project.
   - Move all exposed API keys into Firebase Environment Secrets.
   - Refactor network calls into a secure 'DataService' that interacts with Firebase Cloud Functions/Firestore instead of direct external requests.

3. ARCHITECT & EXPAND:
   - Create a 'Backend' directory.
   - Generate a Dockerfile and a basic Web Dashboard (Next.js) that visualizes the same data as the iOS app, using the Firebase credentials.
   - Ensure the iOS app and the new Web App share the same Firebase 'Source of Truth'.

4. PERSIST:
   - Run 'xcodebuild' and 'docker build' to verify everything works.
   - Raphael, loop and fix any compiler or build errors until the project is 100% functional.
