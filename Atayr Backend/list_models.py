import os
from dotenv import load_dotenv
from google import genai

load_dotenv()
project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")

client = genai.Client(vertexai=True, project=project_id, location=location)

print("Available models:")
for m in client.models.list():
    if "flash" in m.name.lower() or "gemini" in m.name.lower():
        print(m.name)
