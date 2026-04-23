import requests


class POIService:
    # Overpass API endpoints
    OVERPASS_URLS = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
    ]

    # Overpass QL query template for fetching general POIs near a location
    # {lat}, {lng}, {radius} are filled in at request time
    # Each tag key (amenity, leisure, shop, tourism) produces category values
    # used by POIIcons.fromCategory on the client side
    OVERPASS_QUERY = """
[out:json][timeout:20];
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
        # Send the query to the Overpass API, trying each URL in order
        query = self.build_query(lat, lng)
        overpass_response = None
        latest_error = None

        for url in self.OVERPASS_URLS:
            try:
                overpass_response = requests.post(url, data={"data": query}, timeout=25) # Overpass expects the query in a "data" form field
                if overpass_response.status_code == 200:
                    break
                else: # Responses other than 200
                    latest_error = f"HTTP {overpass_response.status_code}: {overpass_response.text}"
                    overpass_response = None
            except requests.RequestException as e:
                latest_error = e
                overpass_response = None

        if overpass_response is None or overpass_response.status_code != 200:
            print(f"Overpass API error: {latest_error}")
            return None

        return overpass_response.json()

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
