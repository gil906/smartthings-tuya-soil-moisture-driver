# SmartThings Edge Driver — Tuya Soil Moisture Sensor (HOBEIAN `ZG-303Z`)

![Zigbee Soil Tester listing — Soil Moisture, Air Temperature, Air Humidity](https://github.com/user-attachments/assets/36ffda18-0b68-4796-ae0e-e3aaf38182b8)

A working SmartThings Edge driver that fixes a real, confirmed bug in how
SmartThings displays data from Tuya-based Zigbee **3-in-1** soil sensors
(soil moisture + air temperature + air humidity — manufacturer `HOBEIAN`,
model `ZG-303Z`, and clones sold under other storefront names with the
same hardware, e.g. "Zigbee Soil Tester Moisture Sensor Temperature
Humidity Meter Luminance Fertility Detector For Tuya Smart Life Z2MQTT
Automation").

**Buy the sensor this driver targets:** [AliExpress listing](https://a.aliexpress.com/_mPCfepD)

## Real-world install

![The actual physical sensor installed in a real potted plant](https://github.com/user-attachments/assets/b670e0d5-b88e-4d80-a5c8-0a7bb21db576)

## Proof it works

![Working in the SmartThings app — Soil Moisture 92%, separate from Humidity 15% and Temperature 67.3°F](https://github.com/user-attachments/assets/2f905d48-5706-4116-8ec9-6a0f9253a28b)

Real device, real app screenshot: Soil Moisture (92%) shown as its own
tile, completely independent from the Temperature/Humidity card below it
(67.3°F / 15%) — confirming the fix actually separates the two signals
correctly instead of conflating them.

![Same device — Air Temperature/Humidity history chart, confirming standard capability history still works normally](https://github.com/user-attachments/assets/1c55e957-1f3c-477d-9fe9-34169c123971)

The Temperature/Humidity card also shows a normal SmartThings history
chart, since those stayed on their standard capabilities. (Note: the
custom Soil Moisture tile does *not* get a history chart in the app —
this is a platform-wide SmartThings limitation on all custom capabilities,
not something specific to this driver; the live value itself is fully
accurate regardless.)

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
- `soil-sensor/profiles/soil-moisture-sensor.yml` — capabilities exposed (custom Soil Moisture, temperature, humidity, battery, refresh); uses the `LeakSensor` device category so the app shows a water-drop moisture icon
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
generic/white-label storefront names, e.g.
["Zigbee Soil Tester Moisture Sensor Temperature Humidity Meter Luminance
Fertility Detector For Tuya Smart Life Z2MQTT Automation"](https://a.aliexpress.com/_mPCfepD)
on AliExpress — reporting soil moisture, air temperature, and air
humidity, requiring a Zigbee 3.0 hub (SmartThings, or Home Assistant with
a Zigbee coordinator).

## Disclaimer

This is a community-built driver, not official Tuya or SmartThings
software. It only affects how the readings are displayed/labeled in
SmartThings — it doesn't change or calibrate the sensor's underlying
hardware measurements in any way.

## License

MIT — see [LICENSE](./LICENSE).
