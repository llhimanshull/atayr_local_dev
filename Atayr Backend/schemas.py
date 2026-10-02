from typing import List, Optional
from pydantic import BaseModel

class BoundingBox(BaseModel):
    x_min: float
    y_min: float
    x_max: float
    y_max: float

class Item(BaseModel):
    id: str
    category: str
    subcategory: str
    name: str
    primary_color: str
    secondary_color: Optional[str] = None
    pattern: str
    style: str
    style_genres: Optional[List[str]] = None
    formality: str
    occasion: str
    season: str
    fit: str
    volume: Optional[str] = None
    material: Optional[str] = None
    visibility: float
    bounding_box: BoundingBox

class Person(BaseModel):
    id: str
    bounding_box: BoundingBox
    garments: List[Item]

class AnalysisResponse(BaseModel):
    people: List[Person]
