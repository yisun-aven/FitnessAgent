# FitnessAgent (MVP)

Agentic health/fitness iOS app MVP.

- iOS app: SwiftUI (iOS 16+), Supabase auth (Google + email), HealthKit reads
- Backend: FastAPI (Python), LangGraph agents, Google Calendar integration (stub)
- Data: Supabase (Auth, Postgres, Storage)

## Repos/Structure
```
/ios/                # SwiftUI app (you'll open in Xcode)
/backend/            # FastAPI app
  app/
    api/             # API routes (goals, tasks, schedule)
    dependencies/    # Auth and shared deps
    agents/          # LangGraph supervisor/workers
    models/          # Pydantic models (schemas)
    main.py          # FastAPI entrypoint
  requirements.txt   # Python deps
  .env.example       # Backend environment variables
/infra/
  supabase/          # SQL schema & RLS policies
README.md
```

## Prerequisites
- Python 3.10+
- Node/Xcode for iOS app
- Supabase project (provided)
- Google Cloud project (for Calendar – later)

## Backend Setup
1) Create and populate `.env` in `backend/` from `.env.example`.
2) Install dependencies and run the server.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

- API root: http://localhost:8000
- Docs: http://localhost:8000/docs

Provide the Supabase JWT access token from the iOS app as `Authorization: Bearer <token>`.

## iOS App Setup (SwiftUI, iOS 16+)
- App name: FitnessAgent
- Bundle ID (suggested): `com.yourcompany.fitnessagent`
- Colors: black & white for MVP

Steps:
1) In Xcode, create a new iOS App project named `FitnessAgent` (SwiftUI, Swift, iOS 16+).
2) Add package dependency: Supabase.swift
   - File → Add Packages → search `https://github.com/supabase-community/supabase-swift`
3) Configure Supabase in your app using the provided URL and anon key from your Supabase project via a Config file or Info.plist.
4) Implement Google OAuth and email/password using Supabase.swift. (We will provide starter SwiftUI views and a simple auth flow in the `ios/` directory as reference.)
5) Make authenticated requests to the backend with the Supabase session access token in the Authorization header.

## Supabase
- Project URL: set in env (see backend/.env.example)
- Anon key: set in iOS app config and in backend env if needed
- Storage bucket (images): create later for photo logging
- SQL schema and RLS policies: see `infra/supabase/`

## Agents (LangGraph)
- Supervisor routes intents
- GoalPlanner refines goals
- TaskGenerator creates tasks
- Scheduler (stub) prepares Calendar insertions

See `backend/app/agents/graph.py`.

## Roadmap (MVP)
- [x] Scaffold backend
- [ ] Scaffold iOS app with Supabase auth screens
- [ ] Implement goals UI and calls to backend
- [ ] Implement task generation via LangGraph
- [ ] Integrate Google Calendar (backend)
- [ ] HealthKit reads (iOS)
- [ ] Photo logging (later)

## Testing
- Use Swagger at `/docs` to test endpoints.
- Supply a valid Supabase user access token (from iOS login) as Bearer token.

## Notes
- Do not commit real secrets. Use `.env` locally and secret managers in production.
- Replace placeholder stubs with Supabase DB CRUD when ready.
