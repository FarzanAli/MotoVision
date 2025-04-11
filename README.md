# MotoVision
An iOS application for connecting to and modifying your motorcycle helmet's MotoVision heads up display

<p align="center">
   <img src="https://github.com/user-attachments/assets/13163c25-3528-4b33-aa1b-12bf582e6de0" width="35%"/>
  <img src="https://github.com/user-attachments/assets/7d0200ec-f200-40c4-bcc2-e1b5492acf9d" width="35%"/>
</p>

https://github.com/user-attachments/assets/08e83533-dcc2-4786-9897-270e23f2cb74


## API Keys Setup

This project uses API keys for various services. To set up your development environment:

1. Copy `Secrets.xcconfig.template` to `Secrets.xcconfig`
2. Replace the placeholder values in `Secrets.xcconfig` with your actual API keys:
   - `WEATHER_API_KEY`: Your OpenWeather API key from [OpenWeather](https://openweathermap.org/api)

Note: Never commit `Secrets.xcconfig` to version control. It is already added to `.gitignore`.
