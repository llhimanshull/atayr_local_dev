import os
import asyncio
from dotenv import load_dotenv
load_dotenv()
from supabase import create_client, Client
from google import genai
from google.genai import types

def create_genai_client():
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
    api_key = os.getenv("GEMINI_API_KEY")

    if project_id:
        return genai.Client(vertexai=True, project=project_id, location=location)
    elif api_key:
        return genai.Client(api_key=api_key)
    else:
        raise ValueError("Must set either GOOGLE_CLOUD_PROJECT or GEMINI_API_KEY")

async def backfill():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    supabase: Client = create_client(url, key)
    client = create_genai_client()
    
    # 1. Fetch all garments where embedding is null
    res = supabase.table("garments").select("*").is_("embedding", "null").execute()
    garments = res.data
    
    if not garments:
        print("No garments need backfilling.")
        return

    print(f"Found {len(garments)} garments to backfill.")
    
    for g in garments:
        garment_id = g["id"]
        print(f"Backfilling {garment_id}...")
        
        desc = (
            f"Category: {g.get('category', 'Unknown')}\n"
            f"Subcategory: {g.get('subcategory', 'Unknown')}\n"
            f"Primary Color: {g.get('primary_color', 'Unknown')}\n"
            f"Secondary Color: {g.get('secondary_color', 'None')}\n"
            f"Pattern: {g.get('pattern', 'Unknown')}\n"
            f"Style: {g.get('style', 'Unknown')}\n"
            f"Fit: {g.get('fit', 'Unknown')}"
        )
        
        contents = []
        try:
            studio_path = g.get("studio_image_path")
            if studio_path:
                img_bytes = supabase.storage.from_("wardrobe").download(studio_path)
                contents.append(types.Part.from_bytes(data=img_bytes, mime_type="image/png"))
        except Exception as e:
            print(f"  Warning: could not download studio image for {garment_id}: {e}")
            
        contents.append(desc)
        
        try:
            response = client.models.embed_content(
                model='text-embedding-004',
                contents=contents
            )
            emb = [float(x) for x in response.embeddings[0].values]
        except Exception as e:
            print(f"  Multimodal embedding failed: {e}. Trying text-only...")
            try:
                response = client.models.embed_content(
                    model='text-embedding-004',
                    contents=[desc]
                )
                emb = [float(x) for x in response.embeddings[0].values]
            except Exception as e2:
                print(f"  Text-only embedding also failed: {e2}")
                continue
                
        # Update garments table
        supabase.table("garments").update({"embedding": emb}).eq("id", garment_id).execute()
        
        # Also update observations for this garment if they exist and are null
        supabase.table("garment_observations").update({"embedding": emb}).eq("garment_id", garment_id).is_("embedding", "null").execute()
        
        print(f"  Successfully backfilled {garment_id}")

if __name__ == "__main__":
    asyncio.run(backfill())
