import os
from dotenv import load_dotenv
from google import genai

load_dotenv()
project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")

client = genai.Client(vertexai=True, project=project_id, location=location)

models_to_test = [
    "imagen-3.0-fast-generate-001",
    "imagegeneration@006",
    "gemini-2.5-pro-image"
]

for m in models_to_test:
    try:
        print(f"Testing {m}...")
        client.models.generate_content(model=m, contents="a cool cat")
        print(f"SUCCESS: {m} is accessible!")
    except Exception as e:
        print(f"FAILED {m}: {str(e)[:150]}")
