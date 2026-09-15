import os
from dotenv import load_dotenv
from google import genai

load_dotenv()
project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")

client = genai.Client(vertexai=True, project=project_id, location=location)

models_to_test = [
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-3.7-flash",
    "gemini-2.5-flash",
    "gemini-3.1-flash-image",
    "gemini-3-pro-image"
]

for m in models_to_test:
    try:
        print(f"Testing {m}...")
        client.models.generate_content(model=m, contents="hi")
        print(f"SUCCESS: {m} is accessible!")
    except Exception as e:
        print(f"FAILED {m}: {str(e)[:150]}")
