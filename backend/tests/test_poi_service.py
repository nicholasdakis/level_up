import pytest
from backend.services.poi_service import POIService


def make_poi(name, lat, lng, amenity=None, leisure=None, shop=None, tourism=None):
    tags = {}
    if name:
        tags["name"] = name
    if amenity:
        tags["amenity"] = amenity
    if leisure:
        tags["leisure"] = leisure
    if shop:
        tags["shop"] = shop
    if tourism:
        tags["tourism"] = tourism
    return {"tags": tags, "lat": lat, "lon": lng}


# build_query tests -----------------

# Coordinates must be correctly injected into the Overpass query template
def test_build_query_contains_coordinates():
    service = POIService()
    query = service.build_query(40.7, -74.0)

    assert "40.7" in query
    assert "-74.0" in query

# Default radius must be 500 meters as per the app's POI search range
def test_build_query_default_radius():
    service = POIService()
    query = service.build_query(0.0, 0.0)

    assert "500" in query

# Custom radius must override the default
def test_build_query_custom_radius():
    service = POIService()
    query = service.build_query(0.0, 0.0, radius=250)

    assert "250" in query

# parse_overpass_response tests -----------------

# Unnamed nodes must be skipped — they have no useful information for the user
def test_parse_overpass_response_skips_unnamed():
    service = POIService()
    data = {"elements": [make_poi(name=None, lat=40.7, lng=-74.0, amenity="cafe")]}

    result = service.parse_overpass_response(data)

    assert len(result) == 0

# A named node must be returned with the correct fields
def test_parse_overpass_response_returns_named():
    service = POIService()
    data = {"elements": [make_poi("Central Perk", 40.7, -74.0, amenity="cafe")]}

    result = service.parse_overpass_response(data)

    assert len(result) == 1
    assert result[0].name == "Central Perk"
    assert result[0].lat == 40.7
    assert result[0].lng == -74.0

# amenity takes priority over other category tags
def test_parse_overpass_response_category_amenity():
    service = POIService()
    data = {"elements": [make_poi("Place", 40.7, -74.0, amenity="restaurant", leisure="park")]}

    result = service.parse_overpass_response(data)

    assert result[0].category == "restaurant"

# leisure is used when amenity is absent
def test_parse_overpass_response_category_leisure():
    service = POIService()
    data = {"elements": [make_poi("Park", 40.7, -74.0, leisure="park")]}

    result = service.parse_overpass_response(data)

    assert result[0].category == "park"

# Nodes with no recognised category tag fall back to "other"
def test_parse_overpass_response_category_fallback():
    service = POIService()
    element = {"tags": {"name": "Mystery Spot"}, "lat": 40.7, "lon": -74.0}
    data = {"elements": [element]}

    result = service.parse_overpass_response(data)

    assert result[0].category == "other"

# Two nodes at the same rounded location must be deduplicated — Overpass sometimes returns duplicates
def test_parse_overpass_response_deduplicates_same_location():
    service = POIService()
    data = {"elements": [
        make_poi("Coffee A", 40.70001, -74.00001, amenity="cafe"),
        make_poi("Coffee B", 40.70001, -74.00001, amenity="cafe"),  # effectively same spot
    ]}

    result = service.parse_overpass_response(data)

    assert len(result) == 1

# Two nodes at genuinely different locations must both be returned
def test_parse_overpass_response_keeps_different_locations():
    service = POIService()
    data = {"elements": [
        make_poi("Place A", 40.7, -74.0, amenity="cafe"),
        make_poi("Place B", 41.0, -73.0, amenity="restaurant"),
    ]}

    result = service.parse_overpass_response(data)

    assert len(result) == 2

# An empty elements list must return an empty result without errors
def test_parse_overpass_response_empty():
    service = POIService()
    result = service.parse_overpass_response({"elements": []})

    assert result == []
