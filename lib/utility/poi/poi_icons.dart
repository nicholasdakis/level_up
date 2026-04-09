import 'package:flutter/material.dart';

// Returns a Material icon based on the POI category string
class POIIcons {
  static IconData fromCategory(String category) {
    switch (category) {
      case 'restaurant':
      case 'fast_food':
      case 'cafe':
      case 'bar':
      case 'pub':
      case 'deli':
        return Icons.restaurant;
      case 'fitness_centre':
      case 'sports_centre':
      case 'gym':
        return Icons.fitness_center;
      case 'park':
      case 'garden':
      case 'playground':
        return Icons.park;
      case 'supermarket':
      case 'convenience':
      case 'bakery':
      case 'greengrocer':
        return Icons.shopping_cart;
      case 'pharmacy':
      case 'hospital':
      case 'clinic':
      case 'doctors':
      case 'dentist':
      case 'optician':
        return Icons.medication_liquid;
      case 'school':
      case 'university':
      case 'college':
      case 'library':
      case 'driving_school':
        return Icons.school;
      case 'hotel':
      case 'hostel':
      case 'guest_house':
        return Icons.hotel;
      case 'museum':
      case 'gallery':
      case 'theatre':
      case 'cinema':
        return Icons.museum;
      case 'weapons':
        return Icons.dangerous_outlined;
      case 'musical_instrument':
        return Icons.music_note;
      case 'taxi':
        return Icons.local_taxi;
      case 'police':
        return Icons.local_police;
      case 'parking':
        return Icons.local_parking;
      case 'bank':
      case 'atm':
        return Icons.attach_money_outlined;
      case 'fuel':
        return Icons.local_gas_station;
      case 'gift':
        return Icons.card_giftcard;
      case 'toilets':
        return Icons.wc_rounded;
      case 'artwork':
        return Icons.brush;
      case 'books':
        return Icons.book;
      case 'recycling':
        return Icons.recycling;
      case 'information':
        return Icons.info_rounded;
      case 'ice_cream':
        return Icons.icecream;
      case 'car_repair':
        return Icons.car_repair;
      case 'dry_cleaning':
        return Icons.dry_cleaning;
      case 'post_office':
        return Icons.local_post_office;
      case 'laundry':
        return Icons.local_laundry_service;
      default:
        return Icons.place; // generic pin for everything else
    }
  }
}
