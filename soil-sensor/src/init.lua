-- Tuya HOBEIAN ZG-303Z Soil Moisture Sensor driver
--
-- Root cause of the original complaint: this sensor has a soil-moisture
-- probe, but instead of using any Tuya-proprietary datapoint for it, the
-- manufacturer reports the live soil moisture reading through the STANDARD
-- Zigbee "Relative Humidity Measurement" cluster (0x0405) -- the same
-- cluster real ambient-humidity sensors use. SmartThings' generic Zigbee
-- humidity driver therefore (correctly, from its own point of view) maps
-- that cluster straight to the standard `relativeHumidityMeasurement`
-- capability, which every automation/dashboard reads as plain room
-- humidity -- even though the number is actually soil moisture.
--
-- VERIFIED 2026-08-25 against two real units (both live-logged while
-- triggering a moisture change): the value reported on cluster 0x0405
-- (RelativeHumidity, attribute 0x0000 MeasuredValue) exactly matches the
-- Tuya EF00 cluster's own datapoint 3 report at the same instant, and both
-- moved together in response to a real moisture change -- confirming this
-- is genuinely the live soil moisture signal, not ambient air humidity,
-- and that no separate/hidden datapoint needs to be hunted down.
--
-- Fix: this driver still listens on the standard RelativeHumidity cluster
-- (so it keeps working with the sensor's real behavior), but instead of
-- mapping it to `relativeHumidityMeasurement`, it emits a dedicated custom
-- "Soil Moisture" capability, so automations/dashboards can no longer
-- confuse it with ambient humidity. Temperature and Battery continue to
-- use their standard Zigbee clusters/capabilities as normal -- only the
-- mislabeled humidity->soil-moisture cluster needed remapping.

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local ZigbeeDriver = require "st.zigbee"
local RelativeHumidity = zcl_clusters.RelativeHumidity

local soilMoisture = capabilities["cablenature06678.soilMoisture"]

local function humidity_to_soil_moisture_handler(driver, device, value, zb_rx)
  -- MeasuredValue is reported as humidity-percent * 100 (standard ZCL
  -- convention), e.g. 1400 => 14.00% -- same math the generic humidity
  -- driver already used, just retargeted to the soil moisture capability.
  local percent = value.value / 100.0
  device:emit_event(soilMoisture.soilMoisture({ value = percent, unit = "%" }))
end

local function do_refresh(driver, device)
  device:send(RelativeHumidity.attributes.MeasuredValue:read(device))
end

local tuya_soil_driver_template = {
  supported_capabilities = {
    soilMoisture,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.refresh,
  },
  zigbee_handlers = {
    attr = {
      [RelativeHumidity.ID] = {
        [RelativeHumidity.attributes.MeasuredValue.ID] = humidity_to_soil_moisture_handler,
      },
    },
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
  },
}

local driver = ZigbeeDriver("tuya-soil-moisture-zg303z", tuya_soil_driver_template)
driver:run()
