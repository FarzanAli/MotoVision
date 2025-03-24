struct OpenWeatherResponse: Decodable {
    let main: Main

    struct Main: Decodable {
        let temp: Double
    }
}
