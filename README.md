# homebus-thermostat-ctrlh-smoke-fan

This is a Homebus-based "thermostat" that turns on and off the laser cutter fan at PDX Hackerspace.

## Usage

On its first run, `homebus-thermostat-ctrlh-smoke-fan` needs to know how to find the HomeBus provisioning server.

```
bundle exec homebus-thermostat-ctrlh-smoke-fan -b homebus-server-IP-or-domain-name -P homebus-server-port
```

The port will usually be 80 (its default value).

Once it's provisioned it stores its provisioning information in `.env.provisioning`.

`homebus-thermostat-ctrlh-smoke-fan` also takes the following command-line options:

- -v | --verbose - verbose mode with lots of informational messages
- -t | --test - do not actually turn the fan on and off

## Configuration

The script is configured via the `.env` file in its directory. This file takes the following values:
- `FAN_CONTROLLER_URL` - URL for the fan controller
- `SMOKE_SENSOR_UUID` Homebus UUID of the smoke sensor
- `TICK_UUID` Homebus UUID of the tick publisher
- `ACCESS_UUID` Homebus UUID of the PDX Hackerspace Access publisher
- `SMOKE_THRESHOLD` - numeric threshold for smoke/particle counts
- `LIGHT_THRESHOLD` - numeric threshold for light
```

## Operation

If the fan is off, the script will turn it on if it the light is on, particle counts are high or someone has recently enabled the laser cutter.

The script will turn the fan off after a period of time after none of these conditions are true.
