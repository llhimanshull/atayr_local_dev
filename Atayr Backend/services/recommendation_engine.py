import random
import itertools
from collections import defaultdict

class OutfitRecommendationEngine:
    """
    Professional fashion stylist engine for Atayr.
    """
    
    CATEGORY_MAPPING = {
        'top': ['top', 'upper', 't-shirt', 'shirt', 'sweatshirt', 'hoodie', 'sweater', 'polo'],
        'bottom': ['bottom', 'bottoms', 'pants', 'jeans', 'skirt', 'shorts', 'cargo', 'trousers', 'joggers'],
        'outerwear': ['outerwear', 'jacket', 'coat', 'blazer', 'cardigan', 'shacket'],
        'footwear': ['footwear', 'shoes', 'sneakers', 'boots', 'slides', 'sandals', 'loafers', 'oxfords'],
        'accessory': ['accessory', 'accessories', 'cap', 'hat', 'watch', 'bandana', 'bag', 'bracelet', 'belt']
    }
    
    FORMALITY_LEVELS = {
        'loungewear': 0,
        'athletic': 1,
        'casual': 2,
        'smart casual': 3,
        'semi-formal': 4,
        'formal': 5,
        'very formal': 6
    }
    
    VOLUME_LEVELS = {
        'skinny': 0,
        'slim': 1,
        'regular': 2,
        'relaxed': 3,
        'baggy': 4,
        'oversized': 5
    }

    # Style world compatibilities (0.0 to 1.0)
    STYLE_MATRIX = {
        'streetwear': {'streetwear': 1.0, 'casual': 0.8, 'athleisure': 0.8, 'workwear': 0.7, 'minimal': 0.5, 'smart casual': 0.2, 'formal': 0.0},
        'casual': {'streetwear': 0.8, 'casual': 1.0, 'athleisure': 0.8, 'workwear': 0.7, 'minimal': 0.8, 'smart casual': 0.7, 'prep': 0.7, 'formal': 0.1},
        'smart casual': {'smart casual': 1.0, 'casual': 0.7, 'minimal': 0.9, 'prep': 0.9, 'formal': 0.6, 'streetwear': 0.2},
        'formal': {'formal': 1.0, 'smart casual': 0.6, 'minimal': 0.6, 'prep': 0.4, 'casual': 0.1, 'streetwear': 0.0},
        'minimal': {'minimal': 1.0, 'casual': 0.8, 'smart casual': 0.9, 'streetwear': 0.5, 'formal': 0.6},
        'prep': {'prep': 1.0, 'smart casual': 0.9, 'casual': 0.7, 'formal': 0.4, 'streetwear': 0.1},
        'workwear': {'workwear': 1.0, 'casual': 0.7, 'streetwear': 0.7, 'minimal': 0.4, 'smart casual': 0.2},
        'athleisure': {'athleisure': 1.0, 'sporty': 1.0, 'casual': 0.8, 'streetwear': 0.8, 'loungewear': 0.8, 'smart casual': 0.1}
    }

    def _get_canonical_category(self, item: dict) -> str:
        cat = item.get('category', '').lower()
        subcat = item.get('subcategory', '').lower()
        for k, v in self.CATEGORY_MAPPING.items():
            if cat in v or subcat in v:
                return k
        return 'accessory'

    def _get_formality(self, item: dict) -> int:
        f = item.get('formality', '').lower()
        if f in self.FORMALITY_LEVELS:
            return self.FORMALITY_LEVELS[f]
        
        # Heuristic fallback
        style = item.get('style', '').lower()
        if 'formal' in style or 'suit' in style or 'oxford' in style or 'blazer' in style: return 5
        if 'smart' in style or 'tailor' in style or 'chino' in style: return 3
        if 'athletic' in style or 'sport' in style or 'gym' in style: return 1
        return 2

    def _get_volume(self, item: dict) -> int:
        v = item.get('volume', '').lower()
        if not v:
            v = item.get('fit', '').lower()
        for key, val in self.VOLUME_LEVELS.items():
            if key in v:
                return val
        return 2 # default regular

    def _get_styles(self, item: dict) -> list[str]:
        styles = item.get('style_genres', [])
        if not styles:
            s = item.get('style', 'casual').lower()
            styles = [s]
        
        mapped = []
        for s in styles:
            s_low = s.lower()
            # Map loosely to known worlds
            if 'street' in s_low or 'skate' in s_low: mapped.append('streetwear')
            elif 'formal' in s_low or 'suit' in s_low: mapped.append('formal')
            elif 'smart' in s_low or 'tailor' in s_low: mapped.append('smart casual')
            elif 'sport' in s_low or 'athleisure' in s_low: mapped.append('athleisure')
            elif 'prep' in s_low or 'ivy' in s_low: mapped.append('prep')
            elif 'minimal' in s_low: mapped.append('minimal')
            elif 'work' in s_low or 'utility' in s_low or 'cargo' in s_low: mapped.append('workwear')
            else: mapped.append('casual')
        return list(set(mapped))

    def _style_compatibility(self, s1: list[str], s2: list[str]) -> float:
        best_score = 0.0
        for a in s1:
            for b in s2:
                score = self.STYLE_MATRIX.get(a, {}).get(b, 0.4) # default 0.4 unknown
                if score > best_score:
                    best_score = score
        return best_score

    def _is_hard_compatible(self, item1: dict, item2: dict) -> bool:
        f1 = self._get_formality(item1)
        f2 = self._get_formality(item2)
        if abs(f1 - f2) >= 3: # 3 steps is too far (e.g. 5 vs 2 -> Formal vs Casual)
            return False
            
        st1 = self._get_styles(item1)
        st2 = self._get_styles(item2)
        if self._style_compatibility(st1, st2) <= 0.2:
            return False
            
        return True

    def _score_silhouette(self, top: dict, bottom: dict) -> float:
        vt = self._get_volume(top)
        vb = self._get_volume(bottom)
        
        # Valid proportions: 
        # Oversized Top (5) + Relaxed Bottom (3) = 8 (Good)
        # Oversized Top (5) + Skinny Bottom (0) = 5 (Can be good streetwear)
        # Skinny Top (0) + Baggy Bottom (4) = 4 (Trendy Y2K)
        
        # Penalize if both are extremely tight or both are max oversized without intent
        if vt == 0 and vb == 0:
            return -2.0 # usually outdated unless specific style
        return 1.0

    def _score_base_outfit(self, outfit_items: list[dict], style_world: str) -> dict:
        """
        Returns a dictionary with 'score', 'focal_points', 'reasons'
        """
        reasons = []
        score = 0.0
        
        # Check hard compatibility across all pairs
        for i1, i2 in itertools.combinations(outfit_items, 2):
            if not self._is_hard_compatible(i1, i2):
                return {'score': -999.0, 'reasons': ['Hard style/formality clash']}
                
        # Formality cohesion
        formalities = [self._get_formality(i) for i in outfit_items]
        avg_f = sum(formalities) / len(formalities)
        variance = sum((f - avg_f) ** 2 for f in formalities) / len(formalities)
        score -= (variance * 1.5)
        
        # Style cohesion with the target style_world
        style_scores = []
        for i in outfit_items:
            sts = self._get_styles(i)
            style_scores.append(max([self.STYLE_MATRIX.get(style_world, {}).get(s, 0.3) for s in sts]))
        
        avg_style = sum(style_scores) / len(style_scores)
        score += (avg_style * 5.0)
        
        # Silhouette
        top = next((i for i in outfit_items if self._get_canonical_category(i) == 'top'), None)
        bottom = next((i for i in outfit_items if self._get_canonical_category(i) == 'bottom'), None)
        if top and bottom:
            score += self._score_silhouette(top, bottom)
            
        # Pattern penalty
        patterns = [i.get('pattern', 'solid').lower() for i in outfit_items]
        strong_patterns = [p for p in patterns if p not in ['solid', 'none', 'plain', 'melange']]
        if len(strong_patterns) > 1:
            score -= 3.0 # Pattern clash penalty
            reasons.append("Multiple strong patterns competing")
            
        return {'score': score, 'reasons': reasons}

    def _get_outfit_signature(self, outfit_items: list[dict]) -> set:
        return frozenset(i.get('id', '') for i in outfit_items)

    def generate_recommendations(self, store_item: dict, wardrobe: list[dict], num_recommendations: int = 5) -> dict:
        store_cat = self._get_canonical_category(store_item)
        store_styles = self._get_styles(store_item)
        
        # Determine candidate style worlds from the store item
        target_worlds = store_styles if store_styles else ['casual']
        
        w_by_cat = {k: [] for k in self.CATEGORY_MAPPING.keys()}
        for item in wardrobe:
            w_by_cat[self._get_canonical_category(item)].append(item)
            
        # Base combinations (Top + Bottom + Footwear)
        templates = []
        if store_cat in ['top', 'bottom', 'footwear', 'accessory']:
            templates.append(['top', 'bottom', 'footwear'])
        elif store_cat == 'outerwear':
            templates.append(['top', 'bottom', 'footwear', 'outerwear'])
            
        valid_combinations = []
        
        for template in templates:
            pools = []
            for cat in template:
                if cat == store_cat:
                    pools.append([store_item])
                else:
                    pools.append(w_by_cat.get(cat, []))
                    
            if any(len(pool) == 0 for pool in pools):
                continue
                
            for combo in itertools.product(*pools):
                outfit = list(combo)
                if store_item not in outfit:
                    outfit.append(store_item)
                    
                # Score outfit against all valid worlds, pick best
                best_world = None
                best_score = -999.0
                best_reasons = []
                
                for world in target_worlds:
                    eval_res = self._score_base_outfit(outfit, world)
                    if eval_res['score'] > best_score:
                        best_score = eval_res['score']
                        best_world = world
                        best_reasons = eval_res['reasons']
                        
                if best_score > 0: # Valid base outfit
                    valid_combinations.append({
                        'items': outfit,
                        'score': best_score,
                        'world': best_world,
                        'reasons': best_reasons
                    })

        # Subtraction / Addition test for Layers & Accessories
        enriched_combinations = []
        for combo in valid_combinations:
            base_items = combo['items']
            best_outfit = base_items
            best_score = combo['score']
            
            # Try adding outerwear if not present
            if store_cat != 'outerwear' and not any(self._get_canonical_category(i) == 'outerwear' for i in base_items):
                for layer in w_by_cat.get('outerwear', []):
                    test_outfit = base_items + [layer]
                    res = self._score_base_outfit(test_outfit, combo['world'])
                    if res['score'] > best_score + 0.5: # Needs to demonstrably improve the outfit
                        best_score = res['score']
                        best_outfit = test_outfit
                        
            # Try adding accessory
            if store_cat != 'accessory':
                for acc in w_by_cat.get('accessory', []):
                    test_outfit = best_outfit + [acc]
                    res = self._score_base_outfit(test_outfit, combo['world'])
                    if res['score'] > best_score + 0.2:
                        best_score = res['score']
                        best_outfit = test_outfit
                        
            enriched_combinations.append({
                'items': best_outfit,
                'score': best_score,
                'world': combo['world']
            })
            
        # Sort and cluster by world
        enriched_combinations.sort(key=lambda x: x['score'], reverse=True)
        
        final_combinations = []
        seen_core = set()
        worlds_represented = set()
        
        for combo in enriched_combinations:
            if len(final_combinations) >= num_recommendations:
                break
                
            core_sig = frozenset(i.get('id', '') for i in combo['items'] if self._get_canonical_category(i) in ['top', 'bottom'])
            world = combo['world']
            
            # Prefer showing diverse worlds if possible, or diverse cores
            if core_sig not in seen_core:
                final_combinations.append(combo)
                seen_core.add(core_sig)
                worlds_represented.add(world)

        # Generate Why It Works
        result_combinations = []
        for combo in final_combinations:
            wardrobe_items = [i for i in combo['items'] if i.get('id') != store_item.get('id')]
            
            # Generate explanation
            world = combo['world'].upper()
            why = f"Why it works: This is a cohesive {world} look. "
            top = next((i for i in combo['items'] if self._get_canonical_category(i) == 'top'), None)
            bot = next((i for i in combo['items'] if self._get_canonical_category(i) == 'bottom'), None)
            shoe = next((i for i in combo['items'] if self._get_canonical_category(i) == 'footwear'), None)
            
            if top and bot and shoe:
                why += f"The {top.get('name', 'top')} and {bot.get('name', 'bottoms')} create a balanced silhouette, anchored by the {shoe.get('name', 'shoes')}."
            
            result_combinations.append({
                "store_item": store_item,
                "wardrobe_items": wardrobe_items,
                "style_direction": world,
                "explanation": why
            })
            
        missing_message = None
        if not final_combinations:
            missing_message = "No fully cohesive outfits could be formed. You may be missing core complementary pieces (like compatible bottoms or footwear) for this item."
        elif not any(self._get_canonical_category(i) == 'footwear' for i in w_by_cat['footwear']):
             missing_message = "Good clothing match found, but suitable footwear for this styling direction is missing from your wardrobe."
             
        return {
            "combinations": result_combinations,
            "missing_message": missing_message
        }
