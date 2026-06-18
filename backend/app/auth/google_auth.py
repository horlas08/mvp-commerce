import os
import httpx
from typing import Optional

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo"


async def verify_google_token(id_token: str) -> Optional[dict]:
    """
    Verify a Google ID token by calling Google's tokeninfo endpoint.
    Returns user info dict with keys: sub, email, name, picture, etc.
    Returns None if verification fails.
    """
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                GOOGLE_TOKEN_INFO_URL,
                params={"id_token": id_token},
                timeout=10.0,
            )

        if response.status_code != 200:
            return None

        data = response.json()

        # Optionally verify the audience matches our client ID
        if GOOGLE_CLIENT_ID and data.get("aud") != GOOGLE_CLIENT_ID:
            return None

        return {
            "google_id": data.get("sub"),
            "email": data.get("email"),
            "name": data.get("name", data.get("email", "").split("@")[0]),
            "picture": data.get("picture"),
            "email_verified": data.get("email_verified", "false") == "true",
        }
    except Exception as e:
        print(f"Google token verification failed: {e}")
        return None
