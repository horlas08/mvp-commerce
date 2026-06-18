import json
import re

log_file = "/Users/user/.gemini/antigravity-ide/brain/369bea57-c737-4628-bcca-d4fde42eddd6/.system_generated/logs/transcript.jsonl"

html_content = ""
with open(log_file, "r") as f:
    for line in f:
        data = json.loads(line)
        if data.get("type") == "USER_INPUT" and "page source" in data.get("content", "") and "<!doctype html>" in data.get("content", ""):
            html_content = data["content"]

print(f"Found HTML content of length: {len(html_content)}")

# Let's save it to a file
with open("/Users/user/project/mvp-commerce/backend/amazon_source.html", "w") as f:
    f.write(html_content)

