import '../models/device_category.dart';

/// Offline lookup service mapping IEEE MAC OUI prefixes to hardware manufacturers
/// and providing device type inference.
class OuiLookup {
  /// Looks up the hardware vendor for a given MAC address string.
  static String lookupVendor(String rawMac) {
    final clean = rawMac
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9A-F]'), '');

    if (clean.length < 6) {
      return 'Unknown Hardware';
    }

    if (clean == 'FFFFFFFFFFFF') {
      return 'Broadcast Address (L2)';
    }

    // Check VRRP / HSRP virtual router prefixes
    if (clean.startsWith('00005E0001')) {
      return 'IETF VRRP Virtual Router';
    }
    if (clean.startsWith('00000C07AC') || clean.startsWith('00000C9F')) {
      return 'Cisco HSRP Virtual Router';
    }
    if (clean.startsWith('01005E')) {
      return 'IPv4 Multicast (IANA)';
    }
    if (clean.startsWith('3333')) {
      return 'IPv6 Multicast (NDP)';
    }

    final oui = clean.substring(0, 6);
    final exact = _ouiDatabase[oui];
    if (exact != null) {
      return exact;
    }

    // Check Locally Administered Address (LAA) bit (2nd hex digit in {2, 6, A, E})
    final firstByte = int.tryParse(clean.substring(0, 2), radix: 16) ?? 0;
    if ((firstByte & 0x02) != 0) {
      return 'Randomized / Private MAC';
    }

    return 'Unknown Vendor';
  }

  /// Suggests a probable [DeviceCategory] based on vendor name and hardware characteristics.
  static DeviceCategory inferCategory(String? vendor, [String? nameHint]) {
    final text = '${vendor ?? ''} ${nameHint ?? ''}'.toLowerCase();

    if (text.contains('router') ||
        text.contains('gateway') ||
        text.contains('mikrotik') ||
        text.contains('pfsense') ||
        text.contains('netgate') ||
        text.contains('sonicwall') ||
        text.contains('fortinet')) {
      return DeviceCategory.router;
    }

    if (text.contains('switch') ||
        text.contains('arista') ||
        text.contains('cisco') ||
        text.contains('extreme networks')) {
      return DeviceCategory.switchDevice;
    }

    if (text.contains('ubiquiti') ||
        text.contains('meraki') ||
        text.contains('aruba') ||
        text.contains('access point') ||
        text.contains('wifi')) {
      return DeviceCategory.accessPoint;
    }

    if (text.contains('server') ||
        text.contains('super micro') ||
        text.contains('dell') ||
        text.contains('vmware') ||
        text.contains('proxmox') ||
        text.contains('qemu') ||
        text.contains('hyper-v')) {
      return DeviceCategory.server;
    }

    if (text.contains('synology') ||
        text.contains('qnap') ||
        text.contains('nas') ||
        text.contains('storage')) {
      return DeviceCategory.nas;
    }

    if (text.contains('printer') ||
        text.contains('xerox') ||
        text.contains('epson') ||
        text.contains('brother') ||
        text.contains('laserjet')) {
      return DeviceCategory.printer;
    }

    if (text.contains('camera') ||
        text.contains('axis') ||
        text.contains('hikvision')) {
      return DeviceCategory.camera;
    }

    if (text.contains('raspberry pi') ||
        text.contains('esp32') ||
        text.contains('espressif') ||
        text.contains('sonos') ||
        text.contains('iot')) {
      return DeviceCategory.iot;
    }

    if (text.contains('apple') ||
        text.contains('iphone') ||
        text.contains('ipad') ||
        text.contains('android') ||
        text.contains('samsung') ||
        text.contains('phone')) {
      return DeviceCategory.mobile;
    }

    if (text.contains('laptop') ||
        text.contains('macbook') ||
        text.contains('thinkpad')) {
      return DeviceCategory.laptop;
    }

    if (text.contains('intel') ||
        text.contains('realtek') ||
        text.contains('msi') ||
        text.contains('asustek') ||
        text.contains('pc')) {
      return DeviceCategory.pc;
    }

    return DeviceCategory.other;
  }

  static const Map<String, String> _ouiDatabase = {
    // Cisco Systems / Meraki
    '00000C': 'Cisco Systems, Inc.',
    '000142': 'Cisco Systems, Inc.',
    '000143': 'Cisco Systems, Inc.',
    '0007EB': 'Cisco Systems, Inc.',
    '000E38': 'Cisco Systems, Inc.',
    '001B54': 'Cisco Systems, Inc.',
    '002255': 'Cisco Systems, Inc.',
    '002584': 'Cisco Systems, Inc.',
    '58AC78': 'Cisco Systems, Inc.',
    'F872EA': 'Cisco Systems, Inc.',
    '00180A': 'Cisco Meraki',
    '881544': 'Cisco Meraki',
    'E0553D': 'Cisco Meraki',

    // Arista / Juniper / Extreme
    '001C73': 'Arista Networks',
    '28993A': 'Arista Networks',
    '444CA8': 'Arista Networks',
    '000585': 'Juniper Networks',
    '2C6BF5': 'Juniper Networks',
    '54E032': 'Juniper Networks',
    '000496': 'Extreme Networks',

    // Firewalls
    '00090F': 'Fortinet, Inc.',
    '704CA5': 'Fortinet, Inc.',
    '906CAC': 'Fortinet, Inc.',
    '001B17': 'Palo Alto Networks',
    '786D94': 'Palo Alto Networks',
    'D4F4BE': 'Palo Alto Networks',
    '0017C5': 'SonicWall',
    '001A8C': 'Sophos Ltd',
    '0008A2': 'Netgate / pfSense',

    // Ubiquiti / MikroTik / TP-Link / Netgear
    '00156D': 'Ubiquiti Inc.',
    '002722': 'Ubiquiti Inc.',
    '245A4C': 'Ubiquiti Inc.',
    '44D9E7': 'Ubiquiti Inc.',
    '7483C2': 'Ubiquiti Inc.',
    '802AA8': 'Ubiquiti Inc.',
    'B4FBE4': 'Ubiquiti Inc.',
    'F09FC2': 'Ubiquiti Inc.',
    '000C42': 'MikroTik (RouterBOARD)',
    '4C5E0C': 'MikroTik (RouterBOARD)',
    '64D154': 'MikroTik (RouterBOARD)',
    'CC2DE0': 'MikroTik (RouterBOARD)',
    'D4CA6D': 'MikroTik (RouterBOARD)',
    '14CC20': 'TP-Link Systems Inc.',
    '50C7BF': 'TP-Link Systems Inc.',
    '98DAC4': 'TP-Link Systems Inc.',
    '00146C': 'NETGEAR',
    '28C68E': 'NETGEAR',
    'A040A0': 'NETGEAR',

    // HPE / Aruba
    '000BCD': 'Hewlett Packard Enterprise',
    '0017A4': 'Hewlett Packard Enterprise',
    '3C4A92': 'Hewlett Packard Enterprise',
    '9457A5': 'Hewlett Packard Enterprise',
    '000B86': 'Aruba Networks (HPE)',
    '24DE9A': 'Aruba Networks (HPE)',
    '6C8814': 'Aruba Networks (HPE)',

    // Hypervisors & Virtualization
    '000569': 'VMware, Inc.',
    '000C29': 'VMware, Inc.',
    '001C14': 'VMware, Inc.',
    '005056': 'VMware, Inc.',
    '525400': 'QEMU / KVM / Proxmox VE',
    'BC2411': 'Proxmox Server Solutions GmbH',
    '00155D': 'Microsoft Hyper-V',
    '0003FF': 'Microsoft Virtual PC',
    '080027': 'Oracle VirtualBox',
    '00163E': 'Xensource / Citrix Hypervisor',
    '0242AC': 'Docker Container Bridge',

    // Servers & Storage
    '001422': 'Dell Inc.',
    '180373': 'Dell Inc.',
    '246E96': 'Dell Inc.',
    'D067E5': 'Dell Inc.',
    'F8BC12': 'Dell Inc.',
    '002590': 'Super Micro Computer, Inc.',
    '0C42A1': 'Super Micro Computer, Inc.',
    '3CECEF': 'Super Micro Computer, Inc.',
    'AC1F6B': 'Super Micro Computer, Inc.',
    '001132': 'Synology Incorporated',
    '9009D0': 'Synology Incorporated',
    '00089B': 'QNAP Systems, Inc.',
    '245EBE': 'QNAP Systems, Inc.',
    '00061B': 'Lenovo / IBM',
    '507B9D': 'Lenovo',
    '98FA9B': 'Lenovo',

    // NICs
    '001320': 'Intel Corporate',
    '001B21': 'Intel Corporate',
    '3C970E': 'Intel Corporate',
    '6805CA': 'Intel Corporate',
    '8C8CAA': 'Intel Corporate',
    'A0369F': 'Intel Corporate',
    'B49691': 'Intel Corporate',
    '00E04C': 'Realtek Semiconductor Corp.',
    '107B44': 'ASUSTek / Realtek NIC',
    '5404A6': 'ASUSTek Computer Inc.',
    '7085C2': 'ASRock / Realtek NIC',
    'D8BBC1': 'Micro-Star INTL (MSI)',
    '001018': 'Broadcom Inc.',
    'B02628': 'Broadcom Inc.',
    '0002C9': 'Mellanox Technologies (NVIDIA)',
    '248A07': 'Mellanox Technologies (NVIDIA)',

    // Apple
    '001CB3': 'Apple, Inc.',
    '186590': 'Apple, Inc.',
    '28CFE9': 'Apple, Inc.',
    '3C0630': 'Apple, Inc.',
    '600308': 'Apple, Inc.',
    '88665A': 'Apple, Inc.',
    'A483E7': 'Apple, Inc.',
    'BC52B7': 'Apple, Inc.',
    'F01898': 'Apple, Inc.',

    // Embedded, SBCs, IoT
    'B827EB': 'Raspberry Pi Foundation',
    'DC2632': 'Raspberry Pi Trading Ltd',
    'D83ADD': 'Raspberry Pi Trading Ltd',
    'E45F01': 'Raspberry Pi Trading Ltd',
    '2CF7F1': 'Seeed Technology Inc.',
    '240AC4': 'Espressif Inc. (ESP32)',
    '30AEA4': 'Espressif Inc. (ESP32/ESP8266)',
    'A4CF12': 'Espressif Inc.',
    '00408C': 'Axis Communications AB (IP Camera)',
    'ACCC8E': 'Axis Communications AB (IP Camera)',
    'B8A44F': 'Axis Communications AB (IP Camera)',
    '2857BE': 'Hikvision Digital Technology',
    '4419B6': 'Hikvision Digital Technology',
    'C056E3': 'Hikvision Digital Technology',
    '0000AA': 'Xerox Corporation',
    '000048': 'Seiko Epson Corporation',
    '001E0B': 'HP Inc. (LaserJet Printer)',
    '30E171': 'HP Inc. (JetDirect Printer)',
    '008077': 'Brother Industries, Ltd.',
    '30055C': 'Brother Industries, Ltd.',
    '001599': 'Samsung Electronics Co.,Ltd',
    '5CE8EB': 'Samsung Electronics Co.,Ltd',
    '000E58': 'Sonos, Inc.',
    '5CAAFD': 'Sonos, Inc.',
  };
}
