const haversine = require('haversine-distance');

const mumbaiSafePlaces = [
    { name: 'Bombay Hospital', type: 'Hospital', lat: 18.9329, lng: 72.8277 },
    { name: 'Tata Memorial Hospital', type: 'Hospital', lat: 19.0189, lng: 72.8468 },
    { name: 'Chhatrapati Shivaji Maharaj Terminus (CST)', type: 'Railway Station', lat: 18.9401, lng: 72.8348 },
    { name: 'Mumbai Central Station', type: 'Railway Station', lat: 18.9666, lng: 72.8213 },
    { name: 'Taj Mahal Palace Hotel', type: 'Hotel', lat: 18.9217, lng: 72.8335 },
    { name: 'The Leela Mumbai', type: 'Hotel', lat: 19.1066, lng: 72.8687 },
    { name: "St. Xavier's College", type: 'School/Shelter', lat: 18.9416, lng: 72.8272 },
    { name: 'Don Bosco School', type: 'School/Shelter', lat: 19.0335, lng: 72.8554 },
    { name: 'BKC Ground', type: 'Shelter', lat: 19.0560, lng: 72.8631 },
    { name: 'Chhatrapati Shivaji Maharaj International Airport', type: 'Airport', lat: 19.0886, lng: 72.8679 },
];

const mumbaiCityLocations = {
   'Colaba': { lat: 18.9151, lng: 72.8141 },
   'colaba': { lat: 18.9151, lng: 72.8141 },
   'Fort': { lat: 18.9353, lng: 72.8370 },
   'fort': { lat: 18.9353, lng: 72.8370 },
   'Worli': { lat: 19.0169, lng: 72.8170 },
   'worli': { lat: 19.0169, lng: 72.8170 },
   'Andheri East': { lat: 19.1197, lng: 72.8468 },
   'andheri east': { lat: 19.1197, lng: 72.8468 },
   'Andheri West': { lat: 19.1301, lng: 72.8331 },
   'andheri west': { lat: 19.1301, lng: 72.8331 },
   'Bandra East': { lat: 19.0596, lng: 72.8405 },
   'bandra east': { lat: 19.0596, lng: 72.8405 },
   'Bandra West': { lat: 19.0544, lng: 72.8402 },
   'bandra west': { lat: 19.0544, lng: 72.8402 },
   'Borivali East': { lat: 19.2312, lng: 72.8566 },
   'borivali east': { lat: 19.2312, lng: 72.8566 },
   'Borivali West': { lat: 19.2360, lng: 72.8331 },
   'borivali west': { lat: 19.2360, lng: 72.8331 },
   'Dadar East': { lat: 19.0176, lng: 72.8495 },
   'dadar east': { lat: 19.0176, lng: 72.8495 },
   'Dadar West': { lat: 19.0168, lng: 72.8424 },
   'dadar west': { lat: 19.0168, lng: 72.8424 },
   'Ghatkopar East': { lat: 19.0855, lng: 72.9089 },
   'ghatkopar east': { lat: 19.0855, lng: 72.9089 },
   'Ghatkopar West': { lat: 19.0863, lng: 72.9075 },
   'ghatkopar west': { lat: 19.0863, lng: 72.9075 },
   'Juhu': { lat: 19.1021, lng: 72.8265 },
   'juhu': { lat: 19.1021, lng: 72.8265 },
   'Kandivali East': { lat: 19.2058, lng: 72.8656 },
   'kandivali east': { lat: 19.2058, lng: 72.8656 },
   'Kandivali West': { lat: 19.2001, lng: 72.8424 },
   'kandivali west': { lat: 19.2001, lng: 72.8424 },
   'Kurla East': { lat: 19.0726, lng: 72.8795 },
   'kurla east': { lat: 19.0726, lng: 72.8795 },
   'Kurla West': { lat: 19.0729, lng: 72.8789 },
   'kurla west': { lat: 19.0729, lng: 72.8789 },
   'Lower Parel': { lat: 18.9930, lng: 72.8303 },
   'lower parel': { lat: 18.9930, lng: 72.8303 },
   'Malad East': { lat: 19.1864, lng: 72.8611 },
   'malad east': { lat: 19.1864, lng: 72.8611 },
   'Malad West': { lat: 19.1850, lng: 72.8410 },
   'malad west': { lat: 19.1850, lng: 72.8410 },
   'Marine Lines': { lat: 18.9430, lng: 72.8261 },
   'marine lines': { lat: 18.9430, lng: 72.8261 },
   'Powai': { lat: 19.1177, lng: 72.9060 },
   'powai': { lat: 19.1177, lng: 72.9060 },
   'Santa Cruz East': { lat: 19.0820, lng: 72.8512 },
   'santa cruz east': { lat: 19.0820, lng: 72.8512 },
   'Santa Cruz West': { lat: 19.0823, lng: 72.8402 },
   'santa cruz west': { lat: 19.0823, lng: 72.8402 },
   'Thane West': { lat: 19.2183, lng: 72.9781 },
   'thane west': { lat: 19.2183, lng: 72.9781 },
   'thane': { lat: 19.2183, lng: 72.9781 },  // Added thane alias
   'Thane': { lat: 19.2183, lng: 72.9781 },
   'Versova': { lat: 19.1343, lng: 72.8128 },
   'versova': { lat: 19.1343, lng: 72.8128 },
   'Vikhroli East': { lat: 19.1121, lng: 72.9289 },
   'vikhroli east': { lat: 19.1121, lng: 72.9289 },
   'Vikhroli West': { lat: 19.1110, lng: 72.9225 },
   'vikhroli west': { lat: 19.1110, lng: 72.9225 },
   'Mumbai': { lat: 19.0760, lng: 72.8777 },  // Added general Mumbai center
   'mumbai': { lat: 19.0760, lng: 72.8777 }
};

exports.findNearestSafePlaces = (originCity) => {
    const originCoords = mumbaiCityLocations[originCity];
    if (!originCoords) {
        return null;
    }

    let nearestPlaces = mumbaiSafePlaces.map(place => {
        const distance = haversine(originCoords, { lat: place.lat, lng: place.lng });

        // ✅ Search by name (more user-friendly)
        const queryName = encodeURIComponent(`${place.name}, Mumbai`);
        const mapLink = `https://www.google.com/maps/search/?api=1&query=${queryName}`;

        // ✅ Optional: Route link using lat,lng (accurate navigation)
        const routeLink = `https://www.google.com/maps/dir/?api=1&origin=${originCoords.lat},${originCoords.lng}&destination=${place.lat},${place.lng}`;

        return {
            ...place,
            distance: (distance / 1000).toFixed(2), // in km
            mapLink,
            routeLink
        };
    }).sort((a, b) => a.distance - b.distance);

    return nearestPlaces.slice(0, 3); // top 3
};
