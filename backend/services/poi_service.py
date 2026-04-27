import concurrent.futures
import requests


class POIService:
    # Overpass API endpoints
    OVERPASS_URLS = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.openstreetmap.ru/api/interpreter",
    ]

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

        def try_url(url):
            # Raises on non-200 so the executor treats it as a failed future
            r = requests.post(url, data={"data": query}, timeout=15)
            if r.status_code == 200:
                return r
            raise Exception(f"HTTP {r.status_code}: {r.text}")

        # ThreadPoolExecutor runs each try_url call in its own thread so all
        # URLs are requested simultaneously instead of one after another
        # executor.submit() schedules a call and immediately returns a Future
        # (a handle to the result that will arrive later)
        # The dict maps each Future back to its URL for error logging.
        executor = concurrent.futures.ThreadPoolExecutor()
        futures = {executor.submit(try_url, url): url for url in self.OVERPASS_URLS}

        # shutdown(wait=False) means the executorgit  won't block when we return early
        # after the first success — the losing thread finishes in the background.
        # Using a 'with' block instead would call shutdown(wait=True) on return,
        # which would wait for both threads to finish before the function returned
        executor.shutdown(wait=False)

        # as_completed() yields each Future in the order they finish,
        # not the order they were submitted, so whichever Overpass server
        # responds first is handled first
        for future in concurrent.futures.as_completed(futures):
            try:
                return future.result().json()  # first success wins
            except Exception as e:
                print(f"Overpass error ({futures[future]}): {e}")
                # loop continues to the next completed future

        # Only reached if every future raised an exception
        print("All Overpass endpoints failed")
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
