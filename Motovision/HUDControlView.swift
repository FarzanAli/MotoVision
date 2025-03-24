import SwiftUI
import CoreBluetooth
import CoreLocation

struct HUDControlView: View {
    @State private var headerText: String = "Welcome!"
    @State private var showTime: Bool = true
    @State private var showWeather: Bool = true
    @State private var selectedMode: DisplayMode = .normal
    @State private var selectedDevice: CBPeripheral?
    @State private var batteryLevel: Double = 0.75
    @State private var isButtonPressed: Bool = false
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var currentTime: String = ""

    enum DisplayMode: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case waze = "Waze"
        
        var id: String { rawValue }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm a"
        return "TIME: " + formatter.string(from: Date())
    }

    var body: some View {
        NavigationView {
            if !bluetoothManager.isConnected {
                // Connection View
                VStack(spacing: 20) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.bottom, 20)
                    
                    Text("Connect to MotoVision")
                        .font(.title2)
                        .bold()
                    
                    Text("Select your HUD display to begin")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    if bluetoothManager.isScanning {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        Button(action: {
                            bluetoothManager.startScanning()
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Scan for Devices")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    if !bluetoothManager.discoveredDevices.isEmpty {
                        List {
                            ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                                Button(action: {
                                    bluetoothManager.connect(to: device)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(device.name ?? "Unknown Device")
                                                .foregroundColor(.primary)
                                            Text(device.identifier.uuidString)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .navigationTitle("MotoVision")
            } else {
                // Main App View
                ScrollView {
                    VStack(spacing: 20) {
                        // OLED Display Preview
                        GroupBox(label: Label("HUD Preview", systemImage: "tv")) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                
                                if selectedMode == .waze {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Alert:")
                                            .foregroundColor(.blue)
                                            .font(.system(.body, design: .monospaced))
                                        
                                        Text("[real-time")
                                            .foregroundColor(.blue)
                                            .font(.system(.body, design: .monospaced))
                                        Text("road alerts]")
                                            .foregroundColor(.blue)
                                            .font(.system(.body, design: .monospaced))
                                        
                                        Text("[Waze Not Linked]")
                                            .foregroundColor(.blue)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.top, 4)
                                        
                                        // Speed Limit Sign - positioned in top right
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 0) {
                                                Text("SPEED")
                                                    .font(.system(.caption2, design: .monospaced))
                                                Text("LIMIT")
                                                    .font(.system(.caption2, design: .monospaced))
                                                Text("60")
                                                    .font(.system(.body, design: .monospaced))
                                            }
                                            .padding(4)
                                            .frame(width: 45)
                                            .background(Color.blue)
                                            .foregroundColor(.black)
                                            .cornerRadius(4)
                                        }
                                        .position(x: 110, y: -40) // Position in top right
                                    }
                                    .padding()
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if showTime {
                                            Text(formattedTime())
                                                .foregroundColor(.blue)
                                                .font(.system(.body, design: .monospaced))
                                        }
                                        
                                        if showWeather {
                                            Text("WEATHER: \(weatherManager.temperature)")
                                                .foregroundColor(.blue)
                                                .font(.system(.body, design: .monospaced))
                                        }
                                        
                                        Text("MOTOVISION HUD")
                                            .foregroundColor(.blue)
                                            .font(.system(.body, design: .monospaced))
                                        
                                        HStack {
                                            Text("BATTERY:")
                                                .foregroundColor(.blue)
                                                .font(.system(.body, design: .monospaced))
                                            
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Color.blue, lineWidth: 1)
                                                    .frame(width: 50, height: 14)
                                                
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(Color.blue)
                                                    .frame(width: 50 * batteryLevel, height: 12)
                                                    .padding(1)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                }
                            }
                            .frame(height: 140) // Reduced height to prevent overflow
                        }

                        // Display Settings
                        GroupBox(label: Text("Display Settings").textCase(.uppercase)) {
                            VStack(spacing: 8) {
                                if selectedMode == .normal {
                                    Toggle("Show Time", isOn: $showTime)
                                    Divider()
                                    Toggle("Show Weather", isOn: $showWeather)
                                }
                            }
                        }

                        // Mode Selection
                        GroupBox(label: Text("Mode").textCase(.uppercase)) {
                            VStack(spacing: 16) {
                                Picker("Display Mode", selection: $selectedMode) {
                                    ForEach(DisplayMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                if selectedMode == .waze {
                                    Button(action: {
                                        // Waze connection would go here
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Connect Waze App")
                                            Image(systemName: "location.fill")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        // display.clearDisplay();

                          // int signWidth = 40;
                          // drawInvertedSpeedLimitSign(SCREEN_WIDTH - signWidth, 0, 60);

                          // u8g2.setFont(u8g2_font_7x13_tf);
                          // u8g2.setCursor(0, 10);
                          // u8g2.print(F("Alert:\n\n[real-time\nroad alerts]"));

                          // u8g2.setCursor(0, 60);
                          // u8g2.print(F("[Waze Not Linked]"));
                          // display.display();
//                        void drawInvertedSpeedLimitSign(int x, int y, int speed) {
//                          int width = 40;
//                          int height = 50;
//                          int cornerRadius = 3;
//
//                          // 1. Fill rounded rectangle
//                          display.fillRoundRect(x, y, width, height, cornerRadius, SSD1306_WHITE);
//
//                          // 2. Draw border
//                          display.drawRoundRect(x, y, width, height, cornerRadius, SSD1306_BLACK);
//
//                          // 3. Black text over white background
//                          display.setTextColor(SSD1306_BLACK);
//
//                          // "SPEED"
//                          display.setTextSize(1);
//                          int speedLabelX = x + (width - 6 * 5) / 2;
//                          display.setCursor(speedLabelX, y + 6);
//                          display.print("SPEED");
//
//                          // "LIMIT"
//                          int limitLabelX = x + (width - 6 * 5) / 2;
//                          display.setCursor(limitLabelX, y + 14);
//                          display.print("LIMIT");
//
//                          // Digits
//                          display.setTextSize(2);  // smaller size for digits to fit in compact sign
//                          String speedStr = String(speed);
//                          int textWidth = speedStr.length() * 6;  // 6px per char at size 1
//                          int speedX = x + (width - 24) / 2;  // 2 chars * 12px ≈ 24px
//
//                          display.setCursor(speedX, y + 30);
//                          display.print(speedStr);
//
//                          // Reset styles
//                          display.setTextColor(SSD1306_WHITE);
//                        }
                        // Send Commands
                        GroupBox(label: Text("Send to Display").textCase(.uppercase)) {
                            Button(action: {
                                var command = "data"
                                if selectedMode == .normal {
                                    if showTime {
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "HH:mm"
                                        let timeString = formatter.string(from: Date())
                                        command += "T:\(timeString);"
                                    }
                                    if showWeather {
                                        command += "W:\(weatherManager.temperature);"
                                    }
                                } else if selectedMode == .waze {
                                    command += "waze;"
                                }
                                bluetoothManager.sendCommand(command + "\n")
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Update Display")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(isButtonPressed ? 0.7 : 1.0))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged({ _ in
                                        isButtonPressed = true
                                    })
                                    .onEnded({ _ in
                                        isButtonPressed = false
                                    })
                            )
                            .padding(8)
                        }

                        // Debug Log
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Debug Log").textCase(.uppercase)
                                    Spacer()
                                    Button("Clear") {
                                        bluetoothManager.clearLog()
                                    }
                                }
                                
                                ScrollView {
                                    Text(bluetoothManager.debugLog)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 200)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("MotoVision")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            bluetoothManager.disconnect()
                        }) {
                            Text("Disconnect")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.currentTime = formattedTime()
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                weatherManager.fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            }
        }
    }
}

#Preview {
    HUDControlView()
}
