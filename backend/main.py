import json
import os

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth, credentials
import firebase_admin
from openai import OpenAI
from pydantic import BaseModel

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AskAiRequest(BaseModel):
    prompt: str
    projectId: str
    projectTitle: str | None = None


class AskAiResponse(BaseModel):
    answer: str


_firebase_ready = False
_openrouter_ready = False
_openrouter_client: OpenAI | None = None


def _init_firebase() -> bool:
    global _firebase_ready
    if _firebase_ready or firebase_admin._apps:
        _firebase_ready = True
        return True

    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    service_account_file = os.getenv("FIREBASE_SERVICE_ACCOUNT_FILE")

    try:
        if service_account_json:
            cred = credentials.Certificate(json.loads(service_account_json))
            firebase_admin.initialize_app(cred)
        elif service_account_file:
            cred = credentials.Certificate(service_account_file)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app()
        _firebase_ready = True
    except Exception:
        _firebase_ready = False

    return _firebase_ready


def _init_openrouter() -> OpenAI | None:
    global _openrouter_ready, _openrouter_client
    if _openrouter_ready and _openrouter_client is not None:
        return _openrouter_client

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        _openrouter_ready = False
        return None

    base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    _openrouter_client = OpenAI(base_url=base_url, api_key=api_key)
    _openrouter_ready = True
    return _openrouter_client


def _require_user(authorization: str | None) -> dict:
    if not _init_firebase():
        raise HTTPException(status_code=500, detail="Firebase admin is not configured.")

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing auth token.")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing auth token.")

    try:
        return auth.verify_id_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid auth token.")


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "firebaseReady": _init_firebase(),
        "openrouterReady": _init_openrouter() is not None,
    }


@app.post("/askai", response_model=AskAiResponse)
def ask_ai(payload: AskAiRequest, authorization: str | None = Header(default=None)) -> AskAiResponse:
    _require_user(authorization)

    prompt = payload.prompt.strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="Prompt is required.")

    client = _init_openrouter()
    if client is None:
        raise HTTPException(status_code=500, detail="OPENROUTER_API_KEY is not configured.")

    model_name = os.getenv("ASKAI_MODEL", "nvidia/nemotron-3-super-120b-a12b:free")
    system_prompt = os.getenv(
        "ASKAI_SYSTEM_PROMPT",
        "You are a helpful study assistant for a student project workspace.",
    )

    project_label = payload.projectTitle or payload.projectId
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Project: {project_label}\nQuestion: {prompt}"},
    ]

    reasoning_enabled = os.getenv("ASKAI_REASONING_ENABLED", "").lower() in {
        "1",
        "true",
        "yes",
    }
    kwargs: dict[str, object] = {}
    if reasoning_enabled:
        kwargs["extra_body"] = {"reasoning": {"enabled": True}}

    result = client.chat.completions.create(
        model=model_name,
        messages=messages,
        **kwargs,
    )
    answer = (result.choices[0].message.content or "").strip()

    if not answer:
        raise HTTPException(status_code=500, detail="AI response was empty.")

    return AskAiResponse(answer=answer)
