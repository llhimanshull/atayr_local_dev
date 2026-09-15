import sys
sys.path.append("d:/Himanshu/Skills/Atayr/Atayr Backend")
import json
from schemas import Garment

raw_json = """
{
  "item_index": 0,
  "outfit_id": "1",
  "category": "accessory",
  "subcategory": "watch",
  "visibility_percent": 100,
  "confidence": 1.0,
  "color_primary": "silver",
  "color_secondary": null,
  "pattern": null,
  "pattern_scale": null,
  "fabric_type": null,
  "surface_light_behavior": "polished",
  "weight": null,
  "fit": null,
  "condition_visible": null
}
"""

try:
    g = Garment(**json.loads(raw_json))
    print("Success:", g)
except Exception as e:
    print("Error:", e)
