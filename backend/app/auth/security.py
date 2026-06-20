import bcrypt

def hash_password(password: str) -> str:
    """Hash a password using bcrypt, truncating to 72 bytes to match bcrypt's hard limit."""
    # Truncate to 72 bytes to match bcrypt's hard limit and prevent ValueError in bcrypt 5.x
    truncated_password = password.encode("utf-8")[:72]
    return bcrypt.hashpw(truncated_password, bcrypt.gensalt()).decode("utf-8")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a hashed password."""
    if not plain_password or not hashed_password:
        return False
    try:
        truncated_password = plain_password.encode("utf-8")[:72]
        # bcrypt.checkpw expects both arguments to be bytes
        return bcrypt.checkpw(truncated_password, hashed_password.encode("utf-8"))
    except (ValueError, AttributeError):
        return False
