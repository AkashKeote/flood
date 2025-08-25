// server/services/floodApi.js

// Dummy data to simulate an external API call
const dummyFloodData = {
    'Andheri East': 'low',
    'andheri east': 'low',
    'Andheri West': 'high',
    'andheri west': 'high',
    'Bandra East': 'moderate',
    'bandra east': 'moderate',
    'Bandra West': 'low',
    'bandra west': 'low',
    'Borivali East': 'high',
    'borivali east': 'high',
    'Borivali West': 'moderate',
    'borivali west': 'moderate',
    'Colaba': 'high',
    'colaba': 'high',
    'Dadar East': 'low',
    'dadar east': 'low',
    'Dadar West': 'high',
    'dadar west': 'high',
    'Fort': 'low',
    'fort': 'low',
    'Ghatkopar East': 'moderate',
    'ghatkopar east': 'moderate',
    'Ghatkopar West': 'high',
    'ghatkopar west': 'high',
    'Juhu': 'low',
    'juhu': 'low',
    'Kandivali East': 'high',
    'kandivali east': 'high',
    'Kandivali West': 'moderate',
    'kandivali west': 'moderate',
    'Kurla East': 'high',
    'kurla east': 'high',
    'Kurla West': 'high',
    'kurla west': 'high',
    'Lower Parel': 'moderate',
    'lower parel': 'moderate',
    'Malad East': 'low',
    'malad east': 'low',
    'Malad West': 'high',
    'malad west': 'high',
    'Marine Lines': 'low',
    'marine lines': 'low',
    'Powai': 'moderate',
    'powai': 'moderate',
    'Santa Cruz East': 'low',
    'santa cruz east': 'low',
    'Santa Cruz West': 'moderate',
    'santa cruz west': 'moderate',
    'Thane West': 'low',
    'thane west': 'low',
    'thane': 'low',  // Added thane as alias for Thane West
    'Thane': 'low',
    'Versova': 'high',
    'versova': 'high',
    'Vikhroli East': 'low',
    'vikhroli east': 'low',
    'Vikhroli West': 'moderate',
    'vikhroli west': 'moderate',
    'Worli': 'high',
    'worli': 'high',
    'Mumbai': 'moderate',  // Added general Mumbai
    'mumbai': 'moderate'
};

exports.getFloodRiskByCity = (city) => {
    // Try exact match first, then lowercase
    const risk = dummyFloodData[city] || dummyFloodData[city.toLowerCase()] || 'low';
    return risk;
};