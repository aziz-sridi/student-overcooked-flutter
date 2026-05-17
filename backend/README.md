# Student Overcooked Backend (FastAPI)

This backend provides the `/askai` endpoint for the Flutter workspace tab.

## Setup

1. Create a virtual environment and install deps:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

2. Create a `.env` from `.env.example` and fill in values:

- `GEMINI_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_FILE` (path to service account JSON)

3. Run the server locally:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

## Flutter configuration

Run Flutter with the backend URL:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8080
```

## Endpoints

- `GET /health`
- `POST /askai`

`POST /askai` expects JSON:

```json
{
  "prompt": "Summarize blockers",
  "projectId": "abc123",
  "projectTitle": "Capstone"
}
```

It requires a Firebase ID token in:

```
Authorization: Bearer <token>
```
