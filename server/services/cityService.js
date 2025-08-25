// Comprehensive city service for flexible city matching
const cityAliases = {
  // Mumbai areas with all possible variations
  'mumbai': ['mumbai', 'bombay', 'mumbai city'],
  'colaba': ['colaba', 'fort colaba'],
  'fort': ['fort', 'fort mumbai', 'mumbai fort'],
  'worli': ['worli', 'worli mumbai'],
  'bandra': ['bandra', 'bandra west', 'bandra east'],
  'bandra west': ['bandra west', 'bandra w', 'west bandra'],
  'bandra east': ['bandra east', 'bandra e', 'east bandra'],
  'andheri': ['andheri', 'andheri west', 'andheri east'],
  'andheri west': ['andheri west', 'andheri w', 'west andheri'],
  'andheri east': ['andheri east', 'andheri e', 'east andheri'],
  'borivali': ['borivali', 'borivali west', 'borivali east'],
  'borivali west': ['borivali west', 'borivali w', 'west borivali'],
  'borivali east': ['borivali east', 'borivali e', 'east borivali'],
  'malad': ['malad', 'malad west', 'malad east'],
  'malad west': ['malad west', 'malad w', 'west malad'],
  'malad east': ['malad east', 'malad e', 'east malad'],
  'kandivali': ['kandivali', 'kandivali west', 'kandivali east'],
  'kandivali west': ['kandivali west', 'kandivali w', 'west kandivali'],
  'kandivali east': ['kandivali east', 'kandivali e', 'east kandivali'],
  'thane': ['thane', 'thane west', 'thane city', 'thane mumbai'],
  'thane west': ['thane west', 'thane w', 'west thane'],
  'ghatkopar': ['ghatkopar', 'ghatkopar west', 'ghatkopar east'],
  'ghatkopar west': ['ghatkopar west', 'ghatkopar w', 'west ghatkopar'],
  'ghatkopar east': ['ghatkopar east', 'ghatkopar e', 'east ghatkopar'],
  'kurla': ['kurla', 'kurla west', 'kurla east'],
  'kurla west': ['kurla west', 'kurla w', 'west kurla'],
  'kurla east': ['kurla east', 'kurla e', 'east kurla'],
  'dadar': ['dadar', 'dadar west', 'dadar east'],
  'dadar west': ['dadar west', 'dadar w', 'west dadar'],
  'dadar east': ['dadar east', 'dadar e', 'east dadar'],
  'santa cruz': ['santa cruz', 'santa cruz west', 'santa cruz east'],
  'santa cruz west': ['santa cruz west', 'santa cruz w', 'west santa cruz'],
  'santa cruz east': ['santa cruz east', 'santa cruz e', 'east santa cruz'],
  'vikhroli': ['vikhroli', 'vikhroli west', 'vikhroli east'],
  'vikhroli west': ['vikhroli west', 'vikhroli w', 'west vikhroli'],
  'vikhroli east': ['vikhroli east', 'vikhroli e', 'east vikhroli'],
  'powai': ['powai', 'hiranandani powai'],
  'juhu': ['juhu', 'juhu beach'],
  'versova': ['versova', 'versova beach'],
  'lower parel': ['lower parel', 'lower', 'parel'],
  'marine lines': ['marine lines', 'marine drive'],
  
  // Add common misspellings and variations
  'bombay': ['bombay', 'mumbai'],
  'thane city': ['thane city', 'thane'],
  'mumbai central': ['mumbai central', 'central mumbai'],
  'south mumbai': ['south mumbai', 'colaba', 'fort'],
  'central mumbai': ['central mumbai', 'dadar', 'lower parel'],
  'north mumbai': ['north mumbai', 'andheri', 'borivali', 'malad'],
  'western mumbai': ['western mumbai', 'bandra', 'juhu', 'versova'],
  'eastern mumbai': ['eastern mumbai', 'ghatkopar', 'vikhroli', 'kurla']
};

// Normalize city name to standard format
function normalizeCityName(cityInput) {
  if (!cityInput) return null;
  
  const input = cityInput.toLowerCase().trim();
  
  // Check if input matches any alias
  for (const [standardCity, aliases] of Object.entries(cityAliases)) {
    if (aliases.includes(input)) {
      return standardCity;
    }
  }
  
  // If no alias found, return the input as is (normalized)
  return input;
}

// Get all possible variations of a city name
function getCityVariations(cityName) {
  const normalized = normalizeCityName(cityName);
  return cityAliases[normalized] || [normalized];
}

// Check if two city names refer to the same place
function isSameCity(city1, city2) {
  const norm1 = normalizeCityName(city1);
  const norm2 = normalizeCityName(city2);
  
  if (norm1 === norm2) return true;
  
  // Check if they share any common aliases
  const variations1 = getCityVariations(city1);
  const variations2 = getCityVariations(city2);
  
  return variations1.some(v1 => variations2.includes(v1));
}

// Get list of all supported cities
function getAllSupportedCities() {
  return Object.keys(cityAliases);
}

module.exports = {
  normalizeCityName,
  getCityVariations,
  isSameCity,
  getAllSupportedCities,
  cityAliases
};
