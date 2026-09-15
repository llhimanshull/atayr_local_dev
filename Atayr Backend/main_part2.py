    dot = sum(a*b for a,b in zip(v1, v2))
    mag1 = sum(a*a for a in v1) ** 0.5
    mag2 = sum(b*b for b in v2) ** 0.5
    if mag1 * mag2 == 0: return 1.0
    return 1.0 - (dot / (mag1 * mag2))

supabase_job_service = SupabaseJobService()

async def process_job_background(job_id: str):
    """
    Background worker that fetches job items, downloads source images,
    runs the AI generation, and uploads results to Supabase.
    Now uses batch processing and deduplication.
    """
    try:
        supabase_job_service.update_job_status(job_id, "processing")
        
        job = supabase_job_service.get_job(job_id)
        if not job:
            print(f"Job {job_id} not found.")
            return

        user_id = job.get("user_id")
        items = supabase_job_service.get_job_items(job_id)
        
        if not items:
            supabase_job_service.update_job_status(job_id, "completed", completed_items=0, failed_items=0)
            return

        completed_count = 0
        failed_count = 0
        
        # Phase 1: Analyze all items and extract garments
        garments_to_process = []
        for item in items:
            if item.get("status") != "queued":
                if item.get("status") == "completed":
                    completed_count += 1
                else:
                    failed_count += 1
                continue
                
            item_id = item["id"]
            source_path = item["source_image_path"]
            
            try:
                supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.1)
                image_data = supabase_job_service.supabase.storage.from_("wardrobe").download(source_path)
                supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.3)
                
                outfit_json = analyze_outfit(image_data, "image/jpeg")
                people = outfit_json.get("people", [])
                
                if not people:
                    supabase_job_service.update_job_item_status(item_id, "failed", error_message="No people found in image.")
                    failed_count += 1
                    continue
                    
                if len(people) > 1:
                    supabase_job_service.update_job_item_status(
                        item_id, "skipped", 
                        error_message="Multiple people detected. Atayr currently works with photos containing one person."
                    )
                    failed_count += 1
                    continue

                garments_found = people[0].get("garments", [])
                for garment_item in garments_found:
                    garments_to_process.append({
                        "item_id": item_id,
                        "source_path": source_path,
                        "image_data": image_data,
                        "garment_item": garment_item
                    })
                    
            except Exception as e:
                print(f"Error analyzing item {item_id}: {e}")
                supabase_job_service.update_job_item_status(item_id, "failed", error_message=str(e))
                failed_count += 1

        # Phase 2: Deduplication and Generation
        # We will keep track of new unique garments created in this batch
        # so intra-batch duplicates map to the same newly created garment ID.
        new_unique_garments = [] # List of dicts: {"garment_id": str, "embedding": list, "category": str}
        
        # Group garments by item_id to update item status properly
        item_progress = {g["item_id"]: 0 for g in garments_to_process}
        
        for g in garments_to_process:
            item_id = g["item_id"]
            garment_item = g["garment_item"]
            image_data = g["image_data"]
            source_path = g["source_path"]
            
            supabase_job_service.update_job_item_status(item_id, "generating", progress=0.5)
            
            embedding, log_data = await asyncio.to_thread(embed_garment, garment_item, image_data)
            category = garment_item.get("category", "Unknown")
            
            if not embedding:
                print(f"Failed to generate embedding for {garment_item.get('name')}")
                continue

            matched_garment_id = None
            
            # 1. Check against DB
            db_candidates = supabase_job_service.match_garment_observation(user_id, category, embedding, threshold=0.15)
            
            # 2. Check against in-memory (intra-batch)
            memory_candidates = []
            for nu in new_unique_garments:
                if nu["category"] == category:
                    dist = cosine_distance(nu["embedding"], embedding)
                    if dist <= 0.15:
                        memory_candidates.append({"garment_id": nu["garment_id"], "similarity": 1.0 - dist})
            
            all_candidates = db_candidates + memory_candidates
            all_candidates.sort(key=lambda x: x["similarity"], reverse=True)
            
            if all_candidates:
                top_candidate = all_candidates[0]
                best_similarity = top_candidate["similarity"]
                best_id = top_candidate["garment_id"]
                
                # High Confidence Match
                if best_similarity >= 0.95: # meaning distance <= 0.05
                    matched_garment_id = best_id
                    print(f"High confidence match ({best_similarity}) for {category}. ID: {best_id}")
                else:
                    # Ambiguous Match (distance between 0.05 and 0.15) -> LLM Verification
                    print(f"Ambiguous match ({best_similarity}) for {category}. Running LLM verification...")
                    
                    # Fetch candidate attributes from DB (only if it's a DB candidate, memory ones we'd have to store)
                    db_candidate_ids = [c["garment_id"] for c in db_candidates[:3]]
                    candidate_records = supabase_job_service.get_garments_by_ids(db_candidate_ids) if db_candidate_ids else []
                    
                    if candidate_records:
                        decision, verified_id = await asyncio.to_thread(
                            verify_garment_duplicate, garment_item, candidate_records, image_data
                        )
                        print(f"LLM Decision: {decision}")
                        if decision == "SAME_GARMENT" and verified_id:
                            matched_garment_id = verified_id
                        elif decision == "SAME_GARMENT":
                            matched_garment_id = best_id # fallback to top if verified_id is missing

            if matched_garment_id:
                # It's a duplicate, just insert observation
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': matched_garment_id,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern"),
                        'style': garment_item.get("style"),
                        'fit': garment_item.get("fit")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            else:
                # It's a new garment, generate studio image
                img_bytes, generated_id = await asyncio.to_thread(
                    generate_garment_image, image_data, "image/jpeg", garment_item
                )
                
                transparent_bytes, bg_status = await asyncio.to_thread(remove_background, img_bytes)
                
                garment_uuid = str(uuid.uuid4())
                studio_image_path = f"{user_id}/garments/{garment_uuid}.png"
                
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=studio_image_path,
                    file=transparent_bytes,
                    file_options={"content-type": "image/png"}
                )
                
                db_row = {
                    'id': garment_uuid,
                    'user_id': user_id,
                    'name': garment_item.get("name", "Generated Garment"),
                    'category': category,
                    'subcategory': garment_item.get("subcategory"),
                    'primary_color': garment_item.get("primary_color"),
                    'secondary_color': garment_item.get("secondary_color"),
                    'pattern': garment_item.get("pattern"),
                    'style': garment_item.get("style"),
                    'fit': garment_item.get("fit"),
                    'studio_image_path': studio_image_path,
                    'source_image_path': source_path,
                    'embedding': embedding, # keeping on garment table too for legacy support
                }
                supabase_job_service.insert_garment(db_row)
                
                # Insert observation
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': garment_uuid,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
                
                # Add to in-memory list so next items in batch can match it
                new_unique_garments.append({
                    "garment_id": garment_uuid,
                    "embedding": embedding,
                    "category": category
                })
        
        # Mark all fully processed items as completed
        processed_item_ids = set([g["item_id"] for g in garments_to_process])
        for item_id in processed_item_ids:
            supabase_job_service.update_job_item_status(item_id, "completed", progress=1.0)
            completed_count += 1

        # Finalize Job Status
        remaining_items = supabase_job_service.supabase.table("processing_job_items").select("*").eq("job_id", job_id).execute()
        
        all_done = True
        for i in remaining_items.data:
            if i["status"] not in ["completed", "failed", "cancelled", "skipped"]:
                all_done = False
                break
                
        if all_done:
            final_status = "completed" if failed_count < len(items) else "failed"
            supabase_job_service.update_job_status(
                job_id, 
                final_status,
                completed_items=completed_count,
                failed_items=failed_count
            )
        
    except Exception as e:
        print(f"Fatal error in background job {job_id}: {e}")
        supabase_job_service.update_job_status(job_id, "failed", error_message=str(e))


async def resume_job_item_background(item_id: str, person_id: str):
    try:
        item = supabase_job_service.supabase.table("processing_job_items").select("*").eq("id", item_id).execute().data[0]
        job_id = item["job_id"]
        user_id = item["user_id"]
        source_path = item["source_image_path"]
        
        supabase_job_service.update_job_item_status(item_id, "analyzing", progress=0.3)
        image_data = supabase_job_service.supabase.storage.from_("wardrobe").download(source_path)
        
        outfit_json = item.get("analysis_data", {})
        people = outfit_json.get("people", [])
        
        target_person = next((p for p in people if p["id"] == person_id), None)
        if not target_person:
            supabase_job_service.update_job_item_status(item_id, "failed", error_message=f"Person {person_id} not found in analysis data.")
            return
            
        garments_found = target_person.get("garments", [])
        
        supabase_job_service.update_job_item_status(item_id, "generating", progress=0.5)
        
        for garment_item in garments_found:
            
            # --- DEDUPLICATION LOGIC (STEP 12) ---
            embedding, log_data = await asyncio.to_thread(embed_garment, garment_item, image_data)
            category = garment_item.get("category", "Unknown")
            
            print(f"\n[DIAGNOSTIC LOG] Garment Processed (Resume Item)")
            print(f"  Job ID: {job_id}")
            print(f"  Photo ID: {item_id}")
            print(f"  Garment Temp ID: {garment_item.get('id', 'unknown')}")
            print(f"  Category: {category}")
            print(f"  Crop Dimensions: {log_data.get('crop_dimensions')}")
            print(f"  Embedding Successfully Generated?: {'YES' if log_data.get('embedding_success') else 'NO'}")
            print(f"  Embedding Fallback Used?: {'YES' if log_data.get('fallback_used') else 'NO'}")
            if log_data.get('fallback_used'):
                print(f"  MULTIMODAL EMBEDDING FAILED")
            print(f"  Embedding Source Type: {log_data.get('embedding_source_type')}")
            
            matched_garment_id = None
            
            db_candidates = supabase_job_service.match_garment_observation(user_id, category, embedding, threshold=0.15)
            if db_candidates:
                top_candidate = db_candidates[0]
                best_similarity = top_candidate["similarity"]
                best_id = top_candidate["garment_id"]
                
                if best_similarity >= 0.95:
                    matched_garment_id = best_id
                    print(f"High confidence match ({best_similarity}) for {category}. ID: {best_id}")
                else:
                    print(f"Ambiguous match ({best_similarity}) for {category}. Running LLM verification...")
                    db_candidate_ids = [c["garment_id"] for c in db_candidates[:3]]
                    candidate_records = supabase_job_service.get_garments_by_ids(db_candidate_ids) if db_candidate_ids else []
                    
                    if candidate_records:
                        decision, verified_id = await asyncio.to_thread(
                            verify_garment_duplicate, garment_item, candidate_records, image_data
                        )
                        if decision == "SAME_GARMENT" and verified_id:
                            matched_garment_id = verified_id
                        elif decision == "SAME_GARMENT":
                            matched_garment_id = best_id
            
            if matched_garment_id:
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': matched_garment_id,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern"),
                        'style': garment_item.get("style"),
                        'fit': garment_item.get("fit")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            else:
                img_bytes, generated_id = await asyncio.to_thread(
                    generate_garment_image, image_data, "image/jpeg", garment_item
                )
                
                transparent_bytes, bg_status = await asyncio.to_thread(
                    remove_background, img_bytes
                )
                
                garment_uuid = str(uuid.uuid4())
                studio_image_path = f"{user_id}/garments/{garment_uuid}.png"
                
                supabase_job_service.supabase.storage.from_("wardrobe").upload(
                    path=studio_image_path,
                    file=transparent_bytes,
                    file_options={"content-type": "image/png"}
                )
                
                db_row = {
                    'id': garment_uuid,
                    'user_id': user_id,
                    'name': garment_item.get("name", "Generated Garment"),
                    'category': category,
                    'subcategory': garment_item.get("subcategory"),
                    'primary_color': garment_item.get("primary_color"),
                    'secondary_color': garment_item.get("secondary_color"),
                    'pattern': garment_item.get("pattern"),
                    'style': garment_item.get("style"),
                    'fit': garment_item.get("fit"),
                    'studio_image_path': studio_image_path,
                    'source_image_path': source_path,
                    'embedding': embedding,
                }
                supabase_job_service.insert_garment(db_row)
                
                obs_uuid = str(uuid.uuid4())
                obs_row = {
                    'id': obs_uuid,
                    'garment_id': garment_uuid,
                    'source_image_path': source_path,
                    'embedding': embedding,
                    'detected_attributes': {
                        'category': category,
                        'subcategory': garment_item.get("subcategory"),
                        'primary_color': garment_item.get("primary_color"),
                        'secondary_color': garment_item.get("secondary_color"),
                        'pattern': garment_item.get("pattern")
                    }
                }
                supabase_job_service.insert_garment_observation(obs_row)
            
        supabase_job_service.update_job_item_status(item_id, "completed", progress=1.0)
        
        # Check if job is fully completed now
        remaining_items = supabase_job_service.supabase.table("processing_job_items").select("*").eq("job_id", job_id).execute()
        all_done = True
        completed_count = 0
        failed_count = 0
        
        for i in remaining_items.data:
            if i["status"] == "completed":
                completed_count += 1
            elif i["status"] == "failed":
                failed_count += 1
            elif i["status"] not in ["completed", "failed", "cancelled"]:
                all_done = False
                
        if all_done:
            final_status = "completed" if failed_count < len(remaining_items.data) else "failed"
            supabase_job_service.update_job_status(
                job_id, 
                final_status,
                completed_items=completed_count,
                failed_items=failed_count
            )
            
    except Exception as e:
        print(f"Fatal error in resuming item {item_id}: {e}")
        supabase_job_service.update_job_item_status(item_id, "failed", error_message=str(e))


@app.post("/process-job/{job_id}")
async def process_job(job_id: str, background_tasks: BackgroundTasks):
    """
    Trigger the backend to start processing an asynchronous job.
    Returns immediately to avoid blocking the client UI.
    """
    background_tasks.add_task(process_job_background, job_id)
    return {"status": "accepted", "job_id": job_id, "message": "Job is processing in the background."}

@app.post("/process-job-item/{item_id}/resume")
async def resume_job_item(item_id: str, person_id: str, background_tasks: BackgroundTasks):
    """
    Resumes processing for a job item that was paused for person selection.
    """
    background_tasks.add_task(resume_job_item_background, item_id, person_id)
    return {"status": "accepted", "message": "Item processing resumed."}
