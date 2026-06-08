import logging
import math
import random
import requests

logger = logging.getLogger(__name__)


class POIService:
    # Overpass API endpoints. tried sequentially, first success wins
    OVERPASS_URLS = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]

    # Identifies the app to Overpass as required by their fair-use policy
    HEADERS = {"User-Agent": "LevelUpApp/1.0 (contact: n1ch0lasd4k1s@gmail.com)"}

    # Overpass QL query template for fetching general POIs near a location
    # {lat}, {lng}, {radius} are filled in at request time
    # Each tag key (amenity, leisure, shop, tourism) produces category values
    # used by POIIcons.fromCategory on the client side
    OVERPASS_QUERY = """
[out:json][timeout:14];
(
  node["amenity"](around:{radius},{lat},{lng});
  node["leisure"](around:{radius},{lat},{lng});
  node["shop"](around:{radius},{lat},{lng});
  node["tourism"](around:{radius},{lat},{lng});
);
out body 100;
"""

    def build_query(self, lat: float, lng: float, radius: int = 500):
        # Fill in the user's coordinates into the Overpass query template
        return self.OVERPASS_QUERY.format(lat=lat, lng=lng, radius=radius)

    def fetch_pois(self, lat: float, lng: float):
        query = self.build_query(lat, lng)

        # Try each URL in order as Overpass's fair-use policy prohibits parallel requests
        for url in self.OVERPASS_URLS:
            try:
                r = requests.post(url, data={"data": query}, headers=self.HEADERS, timeout=15)
                if r.status_code == 200:
                    return r.json()
                logger.warning(f"Overpass error ({url}): HTTP {r.status_code}")
            except requests.RequestException as e:
                logger.warning(f"Overpass error ({url}): {e}")

        logger.error("All Overpass endpoints failed")
        return None

    def parse_overpass_response(self, data):
        # Turn the Overpass JSON into POIItem objects, keeping only named nodes with unique locations
        from backend.schemas import POIItem
        pois = []
        seen_locations = set()
        elements = data.get("elements", []) # Overpass returns results in an "elements" array

        for element in elements:
            tags = element.get("tags", {}) # tags hold metadata like name, amenity type
            name = tags.get("name") # to skip unnamed nodes

            if not name:
                continue

            # Figure out the node's category by going through all categories
            category = (
                tags.get("amenity") or
                tags.get("leisure") or
                tags.get("shop") or
                tags.get("tourism") or
                "other" # fallback
            )

            lat = element["lat"] # Overpass always includes lat/lon for nodes
            lng = element["lon"] # self-note: Overpass uses "lon" for longitude

            # Round to 5 decimal places (1.1m) to prevent duplicate elements returned by Overpass
            location_key = f"{round(lat, 5)},{round(lng, 5)}"
            if location_key in seen_locations:
                continue
            seen_locations.add(location_key)

            pois.append(POIItem(
                name=name,
                lat=lat,
                lng=lng,
                category=category,
            ))

        return pois

    def generate_fake_pois(self, lat: float, lng: float, count: int = 10):
        from backend.schemas import POIItem

        FAKE_POOL = [
            ("Local Park", "park"),
            ("Community Center", "community_centre"),
            ("Nearby Café", "cafe"),
            ("Public Library", "library"),
            ("Sports Court", "pitch"),
            ("Town Square", "plaza"),
            ("Local Gym", "fitness_centre"),
            ("Convenience Store", "convenience"),
            ("Bike Path", "cycling"),
            ("Picnic Area", "picnic_site"),
            ("Walking Trail", "trail"),
            ("Playground", "playground"),
            ("Basketball Court", "pitch"),
            ("Skate Park", "skateboard"),
            ("Dog Park", "park"),
        ]

        # 1 degree of latitude ~ 111,000m; longitude varies by cos(lat)
        lat_per_meter = 1 / 111000
        lng_per_meter = 1 / (111000 * math.cos(math.radians(lat)))

        selected = random.sample(FAKE_POOL, min(count, len(FAKE_POOL)))
        pois = []
        for name, category in selected:
            # Random offset within 400m radius
            distance = random.uniform(100, 400)
            angle = random.uniform(0, 2 * math.pi)
            fake_lat = lat + distance * math.cos(angle) * lat_per_meter
            fake_lng = lng + distance * math.sin(angle) * lng_per_meter
            pois.append(POIItem(
                name=name,
                lat=round(fake_lat, 6),
                lng=round(fake_lng, 6),
                category=category,
            ))
        return pois
