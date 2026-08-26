# SmartThings Edge Driver — Tuya Soil Moisture Sensor (HOBEIAN `ZG-303Z`)

![Soil moisture sensor listing](https://github.com/user-attachments/assets/87b4d6f5-7540-43cb-929b-80b0a7351636)

> **Note on the photo above:** this is a listing image for a similar "3-in-1 Tuya
> Zigbee" soil/temperature/humidity sensor (same product family/behavior as the
> HOBEIAN ZG-303Z this driver targets) — included for a visual reference of what
> this class of sensor looks like and what it measures, not a guaranteed exact
> match to every seller's version. Always confirm your own unit's manufacturer/
> model (see below) before installing.

A working SmartThings Edge driver that fixes a real, confirmed bug in how
SmartThings displays data from Tuya-based Zigbee **3-in-1** soil sensors
(soil moisture + air temperature + air humidity — manufacturer `HOBEIAN`,
model `ZG-303Z`, and clones sold under other storefront names with the
same hardware).

## The problem this fixes

These sensors report three separate readings, but SmartThings' generic
Zigbee humidity driver only ever surfaces two of them correctly
(temperature, and one "Humidity" tile) — it has no concept of "soil
moisture" at all, so the real soil-moisture data was effectively lost/
mislabeled, and the "Humidity" tile shown in the app didn't match either
value cleanly.

**Corrected 2026-08-26** after testing against two real units with live
Zigbee traffic captured: the sensor actually exposes **two independent
percentage values** over two different channels:

- The **standard Zigbee Relative Humidity Measurement cluster** (`0x0405`)
  — this is genuine **ambient/air humidity**. Its value swung widely
  (16% → 51% → 27% → 19%) over a short window, consistent with real
  room-air behavior.
- A **separate Tuya-proprietary datapoint (DP 109 / `0x6D`)** sent over the
  private `0xEF00` cluster — this is the **real soil moisture** reading.
  It stayed steady (~75–76%) over the same window, exactly the stability
  difference you'd expect between soil (changes over hours/days) and air
  (changes minute to minute). This DP number also matches the
  community-documented mapping for this same Tuya soil-sensor hardware
  family in other ecosystems (zigbee-herdsman-converters / ZHA quirks for
  the related ZG-303Z / C3007 devices).

An earlier version of this driver incorrectly assumed the standard
humidity cluster *was* the soil reading and remapped it to "Soil
Moisture" — that was wrong, and has been corrected. See commit history if
curious; this README reflects the current, verified-correct behavior.

## The fix

This driver now reports all three real values, each mapped correctly:

| Sensor channel | SmartThings capability |
|---|---|
| Standard ZCL Temperature cluster | `temperatureMeasurement` (Air Temperature) |
| Standard ZCL RelativeHumidity cluster | `relativeHumidityMeasurement` (Air Humidity) |
| Tuya `0xEF00` cluster, datapoint 109 | Custom **Soil Moisture** capability |
| Standard Battery cluster | `battery` |

The custom Soil Moisture capability is intentionally **read-only** (no
settable/editable field) since the sensor's own hardware is the only real
source of truth for this value — there's nothing to "set" from the app.

## Install it on your own hub

1. Accept the driver channel invite (one-time, links your SmartThings account to this channel):
   **https://bestow-regional.api.smartthings.com/invite/gV2qwyDydYj9**
2. On that page, select your hub to enroll it in the channel.
3. In the SmartThings app: your soil sensor's device page → `...` menu →
   **Driver** → **Select different driver** → pick
   **tuya-soil-moisture-hobeian-zg303z**.
4. You should now see a proper separate **Soil Moisture** tile alongside
   **Humidity** (air) and **Temperature**, instead of soil moisture being
   missing or conflated with room humidity.

## Files

- `soil-sensor/config.yml` — driver metadata, permissions, device type
- `soil-sensor/fingerprints.yml` — maps `HOBEIAN` / `ZG-303Z` to the profile
- `soil-sensor/profiles/soil-moisture-sensor.yml` — capabilities exposed (custom Soil Moisture, temperature, humidity, battery, refresh); uses the official `PlantGrower` device category so the app shows a plant icon instead of a generic sensor icon
- `soil-sensor/src/init.lua` — the actual parsing/mapping logic, fully commented, including the Tuya DP-report parser

## Building/uploading it yourself (if you want your own channel instead)

Requires the official [SmartThings CLI](https://github.com/SmartThingsCommunity/smartthings-cli):

```
smartthings edge:channels:create
smartthings edge:drivers:package ./soil-sensor --channel <your-channel-id>
smartthings edge:drivers:install --hub <your-hub-id> --channel <your-channel-id> <driver-id>
```

You'll also need to create the custom `soilMoisture` capability once under
your own namespace (`smartthings capabilities:create`) and its display
presentation (`smartthings capabilities:presentation:create`) before your
driver can reference it — this repo's `profiles/soil-moisture-sensor.yml`
references a capability ID under this author's namespace
(`cablenature06678.soilMoisture`); swap it for your own if forking.

## The physical device

Targets Tuya Zigbee **3-in-1** soil sensors identifying over Zigbee as
manufacturer `HOBEIAN`, model `ZG-303Z` — commonly sold under various
generic/white-label storefront names (search "Tuya Zigbee 3 in 1 soil
moisture sensor" on AliExpress or similar marketplaces), reporting soil
moisture, air temperature, and air humidity, requiring a Zigbee 3.0 hub
(SmartThings, or Home Assistant with a Zigbee coordinator).

## Disclaimer

This is a community-built driver, not official Tuya or SmartThings
software. It only affects how the readings are displayed/labeled in
SmartThings — it doesn't change or calibrate the sensor's underlying
hardware measurements in any way.

## License

MIT — see [LICENSE](./LICENSE).
