// Flood risk data for Mumbai wards
const floodRiskData = {
    // High Risk Areas
    'Andheri East': 'high',
    'Andheri West': 'high',
    'Bandra East': 'high',
    'Bandra West': 'moderate',
    'Borivali East': 'moderate',
    'Borivali West': 'low',
    'Colaba': 'moderate',
    'Dadar East': 'high',
    'Dadar West': 'high',
    'Ghatkopar East': 'moderate',
    'Ghatkopar West': 'moderate',
    'Goregaon East': 'high',
    'Goregaon West': 'moderate',
    'Juhu': 'high',
    'Kandivali East': 'moderate',
    'Kandivali West': 'low',
    'Kurla East': 'high',
    'Kurla West': 'high',
    'Malad East': 'moderate',
    'Malad West': 'low',
    'Santacruz East': 'high',
    'Santacruz West': 'moderate',
    'Versova': 'high',
    'Vile Parle East': 'moderate',
    'Vile Parle West': 'moderate',
    'Worli': 'moderate',
    'Lower Parel': 'high',
    'Matunga': 'moderate',
    'Sion': 'high',
    'Chembur': 'moderate'
};

function getFloodRiskByCity(city) {
    return floodRiskData[city] || 'low';
}

function getAllHighRiskCities() {
    return Object.keys(floodRiskData).filter(city => floodRiskData[city] === 'high');
}

function getAllModerateRiskCities() {
    return Object.keys(floodRiskData).filter(city => floodRiskData[city] === 'moderate');
}

module.exports = {
    getFloodRiskByCity,
    getAllHighRiskCities,
    getAllModerateRiskCities,
    floodRiskData
};
