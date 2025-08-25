// Safe places in Mumbai for flood emergency
const safePlaces = {
    'Andheri East': [
        { name: 'ISKCON Temple', type: 'Religious Center', distance: 2.5, mapLink: 'https://maps.google.com/?q=ISKCON+Temple+Andheri' },
        { name: 'Gilbert Hill', type: 'High Ground', distance: 3.0, mapLink: 'https://maps.google.com/?q=Gilbert+Hill+Andheri' },
        { name: 'Andheri Sports Complex', type: 'Community Center', distance: 1.8, mapLink: 'https://maps.google.com/?q=Andheri+Sports+Complex' }
    ],
    'Andheri West': [
        { name: 'Versova Beach High Ground', type: 'Elevated Area', distance: 2.2, mapLink: 'https://maps.google.com/?q=Versova+Beach+Mumbai' },
        { name: 'Four Bungalows', type: 'High Ground', distance: 1.5, mapLink: 'https://maps.google.com/?q=Four+Bungalows+Andheri' },
        { name: 'Lokhandwala Complex', type: 'Elevated Residential', distance: 1.0, mapLink: 'https://maps.google.com/?q=Lokhandwala+Complex' }
    ],
    'Bandra East': [
        { name: 'BKC Business District', type: 'High Ground', distance: 2.0, mapLink: 'https://maps.google.com/?q=Bandra+Kurla+Complex' },
        { name: 'Bandra-Worli Sea Link', type: 'Elevated Structure', distance: 1.5, mapLink: 'https://maps.google.com/?q=Bandra+Worli+Sea+Link' }
    ],
    'Bandra West': [
        { name: 'Carter Road Promenade', type: 'Elevated Walkway', distance: 1.0, mapLink: 'https://maps.google.com/?q=Carter+Road+Bandra' },
        { name: 'Bandra Bandstand', type: 'Elevated Area', distance: 1.2, mapLink: 'https://maps.google.com/?q=Bandra+Bandstand' },
        { name: 'Mount Mary Church', type: 'High Ground', distance: 0.8, mapLink: 'https://maps.google.com/?q=Mount+Mary+Church+Bandra' }
    ],
    'Colaba': [
        { name: 'Gateway of India', type: 'Monument Area', distance: 1.0, mapLink: 'https://maps.google.com/?q=Gateway+of+India' },
        { name: 'Taj Hotel', type: 'High-rise Building', distance: 0.8, mapLink: 'https://maps.google.com/?q=Taj+Hotel+Colaba' },
        { name: 'Colaba Causeway', type: 'Elevated Road', distance: 0.5, mapLink: 'https://maps.google.com/?q=Colaba+Causeway' }
    ],
    'Dadar East': [
        { name: 'Shivaji Park', type: 'Open High Ground', distance: 1.5, mapLink: 'https://maps.google.com/?q=Shivaji+Park+Dadar' },
        { name: 'Dadar TT Circle', type: 'Central Location', distance: 1.0, mapLink: 'https://maps.google.com/?q=Dadar+TT+Circle' }
    ],
    'Dadar West': [
        { name: 'Shivaji Park', type: 'Open High Ground', distance: 1.0, mapLink: 'https://maps.google.com/?q=Shivaji+Park+Dadar' },
        { name: 'Portuguese Church', type: 'High Ground', distance: 0.8, mapLink: 'https://maps.google.com/?q=Portuguese+Church+Dadar' }
    ],
    'default': [
        { name: 'Nearest Metro Station', type: 'Underground Safety', distance: 'varies', mapLink: 'https://maps.google.com/?q=Mumbai+Metro+Station' },
        { name: 'Municipal Corporation Office', type: 'Government Building', distance: 'varies', mapLink: 'https://maps.google.com/?q=BMC+Office+Mumbai' },
        { name: 'Nearest Hospital', type: 'Medical Facility', distance: 'varies', mapLink: 'https://maps.google.com/?q=Hospital+Mumbai' }
    ]
};

function findNearestSafePlaces(city) {
    return safePlaces[city] || safePlaces['default'];
}

function getAllSafePlaces() {
    return safePlaces;
}

module.exports = {
    findNearestSafePlaces,
    getAllSafePlaces,
    safePlaces
};
