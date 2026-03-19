# Smart Home Automation System

A production Home Assistant configuration managing 29 automations across lighting, climate, audio, presence detection, and nursery monitoring — built for a two-person household in Philadelphia.

## Why This Project

I wanted full control over my home environment without relying on vendor apps or cloud-dependent routines. Every automation here solves a real daily problem — from adjusting the thermostat based on who's home and the weather, to keeping printer ink from drying out, to making sure the nursery stays in a safe temperature range overnight.

## Tech Stack

| Layer | Tools |
|-------|-------|
| **Platform** | Home Assistant (YAML-configured) |
| **Hardware** | Philips Hue, Ecobee, Sonos, Govee, Hatch Rest, ESP32, Sony TV, Dyson |
| **Protocols** | Zigbee (via Zigbee2MQTT), MQTT, Bluetooth (ESP32 proxy), REST APIs |
| **Network** | Pi-hole (DNS ad-blocking), DuckDNS (dynamic DNS), SSL/TLS |
| **APIs** | OpenMeteo (weather), Govee API (lighting), Pi-hole API, CUPS (printing) |
| **Edge Computing** | ESPHome (ESP32 firmware), AppDaemon (Python automations) |
| **Infrastructure** | Nabu Casa (remote access), HACS (community integrations), Git (auto-backup) |

## Key Automations

### Presence & Geolocation
- **Smart arrival/departure** — lights, thermostat, and eco mode react to who's home using phone GPS zones
- **Approach speed detection** — derivative sensor calculates travel speed; exits eco mode early when approaching fast (≥30 mph)
- **Work departure alerts** — partner gets notified when the other leaves their work zone

### Climate Control
- **Eco mode logic** — thermostat switches to eco when everyone leaves, exits based on outdoor temp thresholds (>76°F cooling, <64°F heating)
- **Guest mode** — a single toggle disables all presence-based thermostat automations so the house stays comfortable for visitors
- **Nursery heater** — maintains 69–71°F range synced with Hatch playback state, with temperature alerts and a 30-minute cooldown to prevent notification spam

### Lighting
- **Brightness caps & syncing** — living room lamps capped at 70%, TV accent lights follow room brightness, stairwell lights sync across floors
- **Time-aware nightlights** — stairwell holds 1% at night, 20% during the day; path lighting triggers for 30 seconds when the bedroom turns off
- **Device coordination** — bar cart light follows room brightness + presence; Dyson heater follows living room light state

### Audio
- **Volume normalization** — Sonos speakers reset to preset levels after 1 hour of inactivity
- **Physical controls** — Hue Tap Dial rotation mapped to Sonos volume with smooth 0.002 increments; button press/hold for mute/unmute
- **Nursery integration** — Hatch playback mutes the hallway light and lowers Sonos volume; morning mode (6–9 AM) turns on first-floor lights

### System Maintenance
- **Nightly Git backup** — shell script auto-commits and pushes config changes at 5 AM with rebase strategy
- **Auto-updates** — all available HA updates applied nightly at 2 AM
- **Monthly printer purge** — AppDaemon Python script prints a test page via CUPS on the 1st of each month to prevent ink dry-out
- **Battery monitoring** — Govee thermometer battery alerts every 6 hours when low

## Custom Integrations

- **Govee** — API-driven light control with IR learning capability and MAC-level device management
- **Hatch Rest Baby** — full nursery device control (RGB light, sound machine, power, toddler lock, scenes) with data coordinator for synced updates
- **HACS** — community store for discovering and managing third-party components

## Architecture Highlights

- **Template sensors** — custom distance-to-home (km→mi conversion), HVAC state detection, weather extraction from API responses, Pi-hole status
- **Derivative + trend sensors** — real-time approach speed calculation from GPS distance changes
- **Dynamic automation discovery** — guest mode script uses repeat loops to programmatically find and toggle thermostat automations
- **Multi-layer conditionals** — automations branch on time of day, device state, presence, weather, and HVAC mode simultaneously
- **ESP32 Bluetooth proxy** — extends BLE coverage to guest bedroom for device connectivity

## File Structure

```
configuration.yaml     # Main config: integrations, sensors, groups, REST commands
automations.yaml       # 29 automations (1,460 lines)
scripts.yaml           # Pi-hole toggle, guest mode control
git_push.sh            # Nightly auto-backup to GitHub
appdaemon/apps/        # Python: monthly printer purge via CUPS
custom_components/     # Govee, Hatch Rest, HACS integrations
esphome/               # ESP32 Bluetooth proxy firmware
blueprints/            # Reusable templates (motion lights, zone alerts, color loops)
```
