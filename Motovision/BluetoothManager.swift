import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var receivedData: String = ""
    @Published var lastError: String?
    @Published var debugLog: String = ""
    @Published var currentDistance: Double = 0.0
    @Published var isAlertActive: Bool = false
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var serialCharacteristic: CBCharacteristic?
    
    // HM-10 service and characteristic UUIDs
    private let serialServiceUUID = CBUUID(string: "FFE0")
    private let serialCharacteristicUUID = CBUUID(string: "FFE1")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        addToLog("BluetoothManager initialized")
    }
    
    private func addToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            self.debugLog += "[\(timestamp)] \(message)\n"
        }
    }
    
    func clearLog() {
        DispatchQueue.main.async {
            self.debugLog = ""
        }
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = "Bluetooth is not available"
            addToLog("❌ Cannot start scanning: Bluetooth not available")
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        addToLog("🔍 Starting scan for HM-10 devices (FFE0)...")
        centralManager.scanForPeripherals(withServices: [serialServiceUUID], options: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        addToLog("⏹️ Scanning stopped")
    }
    
    func connect(to peripheral: CBPeripheral) {
        addToLog("🔌 Attempting to connect to: \(peripheral.name ?? "Unknown")")
        stopScanning()
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            addToLog("📴 Disconnecting from: \(peripheral.name ?? "Unknown")")
            sendCommand("disconnect")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    func sendCommand(_ command: String) {
        print(command);
        guard let characteristic = serialCharacteristic,
              let peripheral = connectedPeripheral else {
            lastError = "Not ready to send command"
            addToLog("❌ Failed to send command: \(command)")
            return
        }
        
        // Add newline to command and convert to data
        let commandWithNewline = command + "\n"
        guard let data = commandWithNewline.data(using: .utf8) else {
            lastError = "Failed to convert command to data"
            addToLog("❌ Failed to convert command to data: \(command)")
            return
        }
        
        addToLog("📤 Sending: \(command) (bytes: \(Array(data)))")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func sendConnectionConfirmation() {
        sendCommand("c")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            lastError = nil
            addToLog("✅ Bluetooth is powered on")
        case .poweredOff:
            lastError = "Bluetooth is turned off"
            isConnected = false
            addToLog("❌ Bluetooth is powered off")
        case .unsupported:
            lastError = "Bluetooth is not supported"
            addToLog("❌ Bluetooth is not supported")
        case .unauthorized:
            lastError = "Bluetooth use is not authorized"
            addToLog("❌ Bluetooth is not authorized")
        case .resetting:
            lastError = "Bluetooth is resetting"
            isConnected = false
            addToLog("⚠️ Bluetooth is resetting")
        case .unknown:
            lastError = "Bluetooth state is unknown"
            addToLog("❓ Bluetooth state is unknown")
        @unknown default:
            lastError = "Unknown Bluetooth state"
            addToLog("❓ Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
            addToLog("📱 Found device: \(peripheral.name ?? "Unknown") (RSSI: \(RSSI)dBm)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        addToLog("✅ Connected to: \(peripheral.name ?? "Unknown")")
        addToLog("🔍 Discovering all services...")
        peripheral.discoverServices(nil)
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.lastError = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.lastError = error?.localizedDescription ?? "Failed to connect"
            self.isConnected = false
            self.addToLog("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPeripheral = nil
            self.serialCharacteristic = nil
            if let error = error {
                self.lastError = "Disconnected: \(error.localizedDescription)"
                self.addToLog("❌ Disconnected with error: \(error.localizedDescription)")
            } else {
                self.addToLog("📴 Disconnected successfully")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            lastError = "Service discovery failed: \(error.localizedDescription)"
            addToLog("❌ Service discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        addToLog("📋 Found \(services.count) services:")
        for service in services {
            addToLog("Service UUID: \(service.uuid.uuidString)")
            if service.uuid == serialServiceUUID {
                addToLog("✅ Found FFE0 service")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            lastError = "Characteristic discovery failed: \(error.localizedDescription)"
            addToLog("❌ Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == serialCharacteristicUUID {
                serialCharacteristic = characteristic
                
                // Log the properties we found
                addToLog("Found FFE1 characteristic with properties:")
                if characteristic.properties.contains(.notify) { addToLog("- Supports notifications") }
                if characteristic.properties.contains(.write) { addToLog("- Supports write") }
                if characteristic.properties.contains(.writeWithoutResponse) { addToLog("- Supports write without response") }
                if characteristic.properties.contains(.read) { addToLog("- Supports read") }
                
                // Enable notifications
                peripheral.setNotifyValue(true, for: characteristic)
                addToLog("✅ Enabled notifications for FFE1 characteristic")
                
                // Send connection confirmation after characteristic is discovered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.addToLog("🤝 Sending connection confirmation...")
                    self?.sendConnectionConfirmation()
                }
                return
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addToLog("❌ Failed to enable notifications: \(error.localizedDescription)")
        } else {
            addToLog("✅ Notification state updated - enabled: \(characteristic.isNotifying)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            lastError = "Read failed: \(error.localizedDescription)"
            addToLog("❌ Read failed: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value,
              let received = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        if received == "connected" {
            DispatchQueue.main.async {
                self.addToLog("✅ Arduino confirmed connection")
            }
        }
        
        DispatchQueue.main.async {
            self.receivedData = received
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addToLog("❌ Write failed: \(error.localizedDescription)")
        } else {
            if let data = characteristic.value {
                addToLog("✅ Write successful - Sent bytes: \(Array(data))")
            } else {
                addToLog("✅ Write successful - No data available")
            }
        }
    }
} 
