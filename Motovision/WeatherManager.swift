import Foundation
import CoreLocation

class WeatherManager: ObservableObject {
    @Published var temperature: String = "---"
    private var lastUpdateTime: Date?
    private var lastLocation: CLLocationCoordinate2D?
    
    func fetchWeather(lat: Double, lon: Double) {
        // Check if we should update the weather
        if let lastUpdate = lastUpdateTime,
           let lastLoc = lastLocation {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            let lastCoordinate = CLLocation(latitude: lastLoc.latitude, longitude: lastLoc.longitude)
            let newCoordinate = CLLocation(latitude: lat, longitude: lon)
            let distance = lastCoordinate.distance(from: newCoordinate)
            
            // Only update if more than 15 minutes have passed or location changed by more than 1km
            guard timeSinceLastUpdate > 900 || distance > 1000 else {
                return
            }
        }
        
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "WEATHER_API_KEY") as? String else {
            print("❌ No API Key found")
            return
        }
        print(" \(lat), \(lon)")
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                    print("🌡 Weather updated: \(decoded.main.temp)°C")
                    
                    DispatchQueue.main.async {
                        self?.temperature = "\(Int(decoded.main.temp))°C"
                        self?.lastUpdateTime = Date()
                        self?.lastLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                } catch {
                    print("❌ Decoding error: \(error)")
                }
            } else if let error = error {
                print("❌ Network error: \(error)")
            }
        }.resume()
    }
}
