/// WeatherGPT Verified Emergency Contacts & Disaster Helplines
/// Stored offline on-device to ensure uninterrupted access during power grid
/// failures, floods, cyclones, network blackouts, and natural disasters.
library;

class EmergencyContact {
  final String title;
  final String number;
  final String description;
  final String icon;

  const EmergencyContact({
    required this.title,
    required this.number,
    required this.description,
    required this.icon,
  });
}

class EmergencyContacts {
  static const List<EmergencyContact> defaultHelplines = [
    EmergencyContact(
      title: 'National Emergency Helpline (All-in-One)',
      number: '112',
      description: 'Single emergency helpline for Police, Fire, and Ambulance across all networks',
      icon: '🚨',
    ),
    EmergencyContact(
      title: 'NDRF Disaster Helpline',
      number: '1078',
      description: 'National Disaster Response Force rescue & evacuation in floods, cyclones, landslides',
      icon: '🌊',
    ),
    EmergencyContact(
      title: 'State Disaster Management Control Room',
      number: '1070',
      description: 'State disaster emergency relief and rescue coordination',
      icon: '🛡️',
    ),
    EmergencyContact(
      title: 'District Disaster Management Helpline',
      number: '1077',
      description: 'Local district collectorate flood, cyclone, and emergency rescue',
      icon: '📍',
    ),
    EmergencyContact(
      title: 'Ambulance & Medical Emergency',
      number: '108',
      description: 'Toll-free emergency medical services and patient transport',
      icon: '🏥',
    ),
    EmergencyContact(
      title: 'Fire & Rescue Service',
      number: '101',
      description: 'Fire control, water rescue, building collapse and hazards',
      icon: '🚒',
    ),
    EmergencyContact(
      title: 'Police Control Room',
      number: '100',
      description: 'Immediate police intervention and law enforcement response',
      icon: '👮',
    ),
    EmergencyContact(
      title: 'IMD Weather & Cyclone Disaster Support',
      number: '1800-180-1717',
      description: 'Official India Meteorological Department severe storm advisory',
      icon: '🌪️',
    ),
  ];
}
