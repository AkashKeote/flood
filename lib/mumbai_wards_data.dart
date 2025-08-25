/// Complete Mumbai Wards Data
/// This file contains all Mumbai wards with their coordinates and flood risk levels
/// Data sourced from Mumbai Municipal Corporation ward divisions

import 'package:flutter/material.dart';

class MumbaiWardsData {
  static final List<Map<String, dynamic>> allWards = [
    // Ward A - South Mumbai
    {'code': 'A', 'name': 'Colaba Causeway', 'lat': 18.9151, 'lng': 72.8141, 'risk': 'Moderate', 'icon': Icons.location_city},
    {'code': 'A', 'name': 'Ballard Estate', 'lat': 18.9496, 'lng': 72.8414, 'risk': 'Moderate', 'icon': 'business'},
    {'code': 'A', 'name': 'Regal Circle', 'lat': 18.9225, 'lng': 72.8312, 'risk': 'Moderate', 'icon': 'account_balance'},
    {'code': 'A', 'name': 'Fort', 'lat': 19.05088346, 'lng': 72.76146598, 'risk': 'Low', 'icon': 'account_balance'},
    {'code': 'A', 'name': 'Metro Cinema Subway', 'lat': 18.9445, 'lng': 72.8279, 'risk': 'Moderate', 'icon': 'train'},
    
    // Ward B - Fort Area
    {'code': 'B', 'name': 'Dongri Circle', 'lat': 18.9594, 'lng': 72.8376, 'risk': 'Moderate', 'icon': 'location_city'},
    {'code': 'B', 'name': 'P D\'Mello Road', 'lat': 18.9556, 'lng': 72.8412, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'B', 'name': 'Carnac Bunder', 'lat': 18.9519, 'lng': 72.8356, 'risk': 'Moderate', 'icon': 'directions_boat'},
    
    // Ward C - CST Area
    {'code': 'C', 'name': 'Marine Lines Subway', 'lat': 18.9458, 'lng': 72.8238, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'C', 'name': 'CST Subway', 'lat': 18.9472, 'lng': 72.8272, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'C', 'name': 'Bhuleshwar', 'lat': 19.07657952, 'lng': 72.84501224, 'risk': 'Low', 'icon': 'storefront'},
    {'code': 'C', 'name': 'Princess Street', 'lat': 18.9494, 'lng': 72.8278, 'risk': 'Moderate', 'icon': 'location_city'},
    
    // Ward E - Byculla Area
    {'code': 'E', 'name': 'Nair Hospital Junction', 'lat': 18.9713, 'lng': 72.8255, 'risk': 'Moderate', 'icon': 'local_hospital'},
    {'code': 'E', 'name': 'Byculla', 'lat': 19.2940447, 'lng': 72.72749992, 'risk': 'Low', 'icon': 'factory'},
    {'code': 'E', 'name': 'Saat Rasta Junction', 'lat': 18.9754, 'lng': 72.8226, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'E', 'name': 'Madanpura', 'lat': 18.94561466, 'lng': 72.94225348, 'risk': 'Low', 'icon': 'home'},
    {'code': 'E', 'name': 'Dockyard Road', 'lat': 18.9637, 'lng': 72.8443, 'risk': 'Moderate', 'icon': 'precision_manufacturing'},
    
    // Ward F/N - Matunga/Sion Area
    {'code': 'F/N', 'name': 'King\'s Circle', 'lat': 19.0272, 'lng': 72.8559, 'risk': 'Moderate', 'icon': 'radio_button_checked'},
    {'code': 'F/N', 'name': 'Sion Circle', 'lat': 19.0373, 'lng': 72.8555, 'risk': 'Moderate', 'icon': 'radio_button_checked'},
    {'code': 'F/N', 'name': 'Gandhi Market', 'lat': 19.0337, 'lng': 72.8512, 'risk': 'Moderate', 'icon': 'storefront'},
    {'code': 'F/N', 'name': 'Matunga', 'lat': 19.11092885, 'lng': 72.98558095, 'risk': 'Low', 'icon': 'train'},
    {'code': 'F/N', 'name': 'Five Gardens', 'lat': 19.0163, 'lng': 72.8494, 'risk': 'Moderate', 'icon': 'park'},
    {'code': 'F/N', 'name': 'Wadala', 'lat': 18.87827989, 'lng': 72.84007918, 'risk': 'Low', 'icon': 'factory'},
    {'code': 'F/N', 'name': 'Hindmata Junction', 'lat': 19.0199, 'lng': 72.8439, 'risk': 'Moderate', 'icon': 'traffic'},
    
    // Ward F/S - Sewri Area  
    {'code': 'F/S', 'name': 'Naigaon Cross Road', 'lat': 19.0081, 'lng': 72.8367, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'F/S', 'name': 'Sewri', 'lat': 19.27535715, 'lng': 72.91959818, 'risk': 'Low', 'icon': 'factory'},
    {'code': 'F/S', 'name': 'Jerbai Wadia Road', 'lat': 19.0049, 'lng': 72.8397, 'risk': 'Moderate', 'icon': 'directions_walk'},
    
    // Ward G/N - Dadar/Mahim Area
    {'code': 'G/N', 'name': 'Dadar TT', 'lat': 19.0195, 'lng': 72.8436, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'G/N', 'name': 'Mahim', 'lat': 19.06413713, 'lng': 72.88843952, 'risk': 'Low', 'icon': 'directions_boat'},
    {'code': 'G/N', 'name': 'LJ Road Junction', 'lat': 19.0372, 'lng': 72.8401, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'G/N', 'name': 'Dharavi', 'lat': 19.14503768, 'lng': 72.81711293, 'risk': 'Low', 'icon': 'home'},
    {'code': 'G/N', 'name': 'Kirti College', 'lat': 19.0294, 'lng': 72.8371, 'risk': 'Moderate', 'icon': 'school'},
    {'code': 'G/N', 'name': 'Lady Jamshedji Road', 'lat': 19.0299, 'lng': 72.8393, 'risk': 'Moderate', 'icon': 'directions_walk'},
    
    // Ward G/S - Worli Area
    {'code': 'G/S', 'name': 'Worli', 'lat': 19.12385454, 'lng': 72.85079194, 'risk': 'Low', 'icon': 'business_center'},
    {'code': 'G/S', 'name': 'Elphinstone Bridge', 'lat': 19.0172, 'lng': 72.8337, 'risk': 'Moderate', 'icon': 'account_balance'},
    {'code': 'G/S', 'name': 'Prabhadevi', 'lat': 18.81233498, 'lng': 72.82206953, 'risk': 'Low', 'icon': 'temple_hindu'},
    {'code': 'G/S', 'name': 'Tulsi Pipe Road', 'lat': 19.0098, 'lng': 72.8319, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'G/S', 'name': 'Worli Naka', 'lat': 19.0056, 'lng': 72.8199, 'risk': 'Moderate', 'icon': 'waves'},
    
    // Ward H/E - Kalina Area
    {'code': 'H/E', 'name': 'Kalina CST Road', 'lat': 19.0802, 'lng': 72.8655, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'H/E', 'name': 'Air India Colony', 'lat': 19.084, 'lng': 72.87, 'risk': 'Moderate', 'icon': 'flight'},
    {'code': 'H/E', 'name': 'Kalina University', 'lat': 19.0722, 'lng': 72.8673, 'risk': 'Moderate', 'icon': 'school'},
    {'code': 'H/E', 'name': 'Vakola Nala', 'lat': 19.0754, 'lng': 72.8517, 'risk': 'Moderate', 'icon': 'water'},
    
    // Ward H/W - Bandra Area
    {'code': 'H/W', 'name': 'Linking Road', 'lat': 19.0543, 'lng': 72.8301, 'risk': 'Moderate', 'icon': 'storefront'},
    {'code': 'H/W', 'name': 'Khar West', 'lat': 19.1646607, 'lng': 72.77101183, 'risk': 'Low', 'icon': 'train'},
    {'code': 'H/W', 'name': 'SV Road Khar', 'lat': 19.0717, 'lng': 72.8391, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'H/W', 'name': 'Santacruz West', 'lat': 19.18868656, 'lng': 72.8743115, 'risk': 'Low', 'icon': 'flight'},
    {'code': 'H/W', 'name': 'Waterfield Road', 'lat': 19.0605, 'lng': 72.8335, 'risk': 'Moderate', 'icon': 'directions_walk'},
    
    // Ward K/E - Andheri East
    {'code': 'K/E', 'name': 'Saki Naka Junction', 'lat': 19.1031, 'lng': 72.8882, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'K/E', 'name': 'Marol Naka', 'lat': 19.1049, 'lng': 72.8837, 'risk': 'Moderate', 'icon': 'business'},
    {'code': 'K/E', 'name': 'JB Nagar Metro', 'lat': 19.1089, 'lng': 72.8664, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'K/E', 'name': 'Andheri East', 'lat': 18.87387316, 'lng': 72.82843701, 'risk': 'Low', 'icon': 'apartment'},
    {'code': 'K/E', 'name': 'Airport Gate 8', 'lat': 19.0995, 'lng': 72.8662, 'risk': 'Moderate', 'icon': 'flight'},
    
    // Ward K/W - Andheri West
    {'code': 'K/W', 'name': 'SV Road Andheri', 'lat': 19.1182, 'lng': 72.8463, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'K/W', 'name': 'Oshiwara Nullah', 'lat': 19.1482, 'lng': 72.8273, 'risk': 'Moderate', 'icon': 'water'},
    {'code': 'K/W', 'name': 'Vile Parle West', 'lat': 18.88830685, 'lng': 72.86461588, 'risk': 'Low', 'icon': 'train'},
    {'code': 'K/W', 'name': 'DN Nagar Metro', 'lat': 19.136, 'lng': 72.8314, 'risk': 'Moderate', 'icon': 'train'},
    
    // Ward P/N - Malad North
    {'code': 'P/N', 'name': 'Kurar Village', 'lat': 19.1903, 'lng': 72.8605, 'risk': 'Moderate', 'icon': 'nature'},
    {'code': 'P/N', 'name': 'Pathanwadi', 'lat': 19.1834, 'lng': 72.8701, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'P/N', 'name': 'Marve', 'lat': 18.84279647, 'lng': 72.92839484, 'risk': 'Low', 'icon': 'beach_access'},
    {'code': 'P/N', 'name': 'Pushpa Park', 'lat': 19.1853, 'lng': 72.8623, 'risk': 'Moderate', 'icon': 'park'},
    {'code': 'P/N', 'name': 'Western Express Highway', 'lat': 19.1906, 'lng': 72.8636, 'risk': 'Moderate', 'icon': 'local_shipping'},
    
    // Ward P/S - Goregaon
    {'code': 'P/S', 'name': 'MG Road', 'lat': 19.1598, 'lng': 72.8445, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'P/S', 'name': 'Siddharth Hospital', 'lat': 19.1639, 'lng': 72.8433, 'risk': 'Moderate', 'icon': 'local_hospital'},
    {'code': 'P/S', 'name': 'Goregaon', 'lat': 18.99427905, 'lng': 72.83460809, 'risk': 'Low', 'icon': 'train'},
    {'code': 'P/S', 'name': 'Motilal Nagar', 'lat': 19.1613, 'lng': 72.8407, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'P/S', 'name': 'Goregaon Station', 'lat': 19.1555, 'lng': 72.8441, 'risk': 'Moderate', 'icon': 'train'},
    
    // Ward R/N - Dahisar
    {'code': 'R/N', 'name': 'Dahisar Subway', 'lat': 19.2525, 'lng': 72.8601, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'R/N', 'name': 'Ovaripada', 'lat': 19.2536, 'lng': 72.8682, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'R/N', 'name': 'Dahisar', 'lat': 18.85334504, 'lng': 72.97523957, 'risk': 'Low', 'icon': 'nature'},
    
    // Ward R/S - Kandivali
    {'code': 'R/S', 'name': 'Shimpoli Road', 'lat': 19.2064, 'lng': 72.8376, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'R/S', 'name': 'Poinsur Depot', 'lat': 19.2083, 'lng': 72.8361, 'risk': 'Moderate', 'icon': 'directions_bus'},
    {'code': 'R/S', 'name': 'Kandivali', 'lat': 19.03759446, 'lng': 72.74871077, 'risk': 'Low', 'icon': 'train'},
    {'code': 'R/S', 'name': 'Mahavir Nagar', 'lat': 19.206, 'lng': 72.83, 'risk': 'Moderate', 'icon': 'home'},
    
    // Ward R/C - Borivali
    {'code': 'R/C', 'name': 'IC Colony Subway', 'lat': 19.2365, 'lng': 72.8322, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'R/C', 'name': 'Mandapeshwar Creek', 'lat': 19.2408, 'lng': 72.8173, 'risk': 'Moderate', 'icon': 'water'},
    {'code': 'R/C', 'name': 'Borivali', 'lat': 18.87866314, 'lng': 72.73566232, 'risk': 'Low', 'icon': 'nature'},
    
    // Ward L - Kurla
    {'code': 'L', 'name': 'Kurla Station', 'lat': 19.0727, 'lng': 72.8826, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'L', 'name': 'Bail Bazaar', 'lat': 19.0722, 'lng': 72.8771, 'risk': 'Moderate', 'icon': 'storefront'},
    {'code': 'L', 'name': 'LBS Road Phoenix', 'lat': 19.0888, 'lng': 72.8861, 'risk': 'Moderate', 'icon': 'shopping_cart'},
    {'code': 'L', 'name': 'CST Road Nullah', 'lat': 19.0813, 'lng': 72.8711, 'risk': 'Moderate', 'icon': 'water'},
    
    // Ward M/E - Chembur East
    {'code': 'M/E', 'name': 'Shivaji Nagar', 'lat': 19.0572, 'lng': 72.8999, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'M/E', 'name': 'Baiganwadi', 'lat': 19.0566, 'lng': 72.9021, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'M/E', 'name': 'Chembur East Bus Depot', 'lat': 19.0524, 'lng': 72.9005, 'risk': 'Moderate', 'icon': 'directions_bus'},
    
    // Ward M/W - Chembur West
    {'code': 'M/W', 'name': 'Mahul Village', 'lat': 19.0054, 'lng': 72.8841, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'M/W', 'name': 'RC Marg', 'lat': 19.0443, 'lng': 72.8943, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'M/W', 'name': 'Shell Colony', 'lat': 19.0431, 'lng': 72.8995, 'risk': 'Moderate', 'icon': 'factory'},
    {'code': 'M/W', 'name': 'Chembur', 'lat': 19.27786647, 'lng': 72.73192718, 'risk': 'Low', 'icon': 'train'},
    {'code': 'M/W', 'name': 'Trombay Road', 'lat': 19.0005, 'lng': 72.8873, 'risk': 'Moderate', 'icon': 'factory'},
    
    // Ward N - Ghatkopar
    {'code': 'N', 'name': 'Pant Nagar', 'lat': 19.0845, 'lng': 72.9107, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'N', 'name': 'Amar Mahal Junction', 'lat': 19.0594, 'lng': 72.9084, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'N', 'name': 'RB Kadam Marg', 'lat': 19.0898, 'lng': 72.9156, 'risk': 'Moderate', 'icon': 'directions_walk'},
    
    // Ward S - Bhandup/Kanjurmarg
    {'code': 'S', 'name': 'Bhandup Tank Road', 'lat': 19.1436, 'lng': 72.9357, 'risk': 'Moderate', 'icon': 'water'},
    {'code': 'S', 'name': 'LBS Marg Bhandup', 'lat': 19.1413, 'lng': 72.9341, 'risk': 'Moderate', 'icon': 'train'},
    {'code': 'S', 'name': 'Kanjurmarg', 'lat': 18.98606011, 'lng': 72.8565653, 'risk': 'Low', 'icon': 'train'},
    {'code': 'S', 'name': 'Ganesh Nagar', 'lat': 19.1145, 'lng': 72.9306, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'S', 'name': 'Bhandup', 'lat': 18.96848239, 'lng': 72.78874401, 'risk': 'Low', 'icon': 'nature'},
    
    // Ward T - Mulund
    {'code': 'T', 'name': 'Mehul Circle', 'lat': 19.1741, 'lng': 72.9592, 'risk': 'Moderate', 'icon': 'radio_button_checked'},
    {'code': 'T', 'name': 'Mulund', 'lat': 19.13907889, 'lng': 72.94062611, 'risk': 'Low', 'icon': 'terrain'},
    {'code': 'T', 'name': 'Sarojini Naidu Road', 'lat': 19.172, 'lng': 72.9554, 'risk': 'Moderate', 'icon': 'directions_walk'},
    {'code': 'T', 'name': 'Lok Rachana Society', 'lat': 19.1748, 'lng': 72.9426, 'risk': 'Moderate', 'icon': 'home'},
    {'code': 'T', 'name': 'Panch Rasta', 'lat': 19.1735, 'lng': 72.9478, 'risk': 'Moderate', 'icon': 'traffic'},
    {'code': 'T', 'name': 'Mulund Railway', 'lat': 19.1728, 'lng': 72.9473, 'risk': 'Moderate', 'icon': 'train'},
  ];

  /// Get wards by risk level
  static List<Map<String, dynamic>> getWardsByRisk(String riskLevel) {
    return allWards.where((ward) => 
        ward['risk'].toLowerCase() == riskLevel.toLowerCase()).toList();
  }

  /// Get wards by ward code
  static List<Map<String, dynamic>> getWardsByCode(String wardCode) {
    return allWards.where((ward) => 
        ward['code'] == wardCode).toList();
  }

  /// Search wards by name
  static List<Map<String, dynamic>> searchWards(String query) {
    if (query.isEmpty) return allWards;
    
    return allWards.where((ward) => 
        ward['name'].toLowerCase().contains(query.toLowerCase())).toList();
  }

  /// Get unique ward codes
  static List<String> getUniqueWardCodes() {
    return allWards.map((ward) => ward['code'].toString()).toSet().toList()..sort();
  }

  /// Get ward statistics
  static Map<String, int> getWardStatistics() {
    Map<String, int> stats = {
      'total': allWards.length,
      'low_risk': 0,
      'moderate_risk': 0,
      'high_risk': 0,
    };

    for (var ward in allWards) {
      String risk = ward['risk'].toLowerCase();
      if (risk == 'low') {
        stats['low_risk'] = stats['low_risk']! + 1;
      } else if (risk == 'moderate') {
        stats['moderate_risk'] = stats['moderate_risk']! + 1;
      } else if (risk == 'high') {
        stats['high_risk'] = stats['high_risk']! + 1;
      }
    }

    return stats;
  }
}
