# Home Assistant Energy Monitor

A production Home Assistant configuration running 31 automations across lighting, climate, audio, presence detection, and nursery monitoring for a two-person household.

[Screenshot](https://raw.githubusercontent.com/acr197/home-assistant-automations/main/Home%20Assistant%20Energy%20Monitoring%20Dashboard.png)

## Features

- Presence-based climate control that switches to eco mode when everyone leaves and exits based on outdoor temperature thresholds
- Nursery heater that holds a 69 to 71 F range, synced to the Hatch sound machine state, with alerts and a cooldown to prevent notification spam
- Guest mode toggle that disables all presence-based thermostat automations with one switch
- Dashboard Pi-hole button that pauses DNS ad-blocking for 15 minutes with a live countdown, then re-enables automatically
- Wake Desktop tile that wakes the PC over LAN and shows it as running via a per-minute heartbeat the PC itself POSTs to a webhook (Windows scheduled task in `desktop/`), with smart-plug wattage as fallback
- Time-aware lighting with brightness caps, room syncing, and nightlight behavior that adjusts by time of day
- Hue Tap Dial mapped to Sonos volume with smooth 0.002 increments, plus button press and hold for mute and unmute
- Nightly Git backup that auto-commits and pushes config changes at 5 AM
- Bi-weekly printer test page via AppDaemon to prevent ink dry-out

## Tech Stack

- **Home Assistant** on a Raspberry Pi, configured entirely in YAML
- **Zigbee2MQTT** and **MQTT** for device communication
- **ESP32 with ESPHome** as a Bluetooth proxy extending BLE coverage
- **AppDaemon (Python)** for automations that need more logic than YAML allows, like the printer purge via CUPS
- **OpenMeteo API** for weather data used in climate decisions
- **DuckDNS** for dynamic DNS with SSL/TLS for remote access
- Hardware includes Philips Hue, Ecobee, Sonos, Govee, Hatch Rest, Dyson, and Sony TV

## Privacy

- Runs entirely on local hardware. No cloud dependency for automations.
- Remote access uses DuckDNS dynamic DNS with SSL/TLS.
- Weather data is the only external API call. No telemetry or third-party analytics.
