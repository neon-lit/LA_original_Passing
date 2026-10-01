# App Review Notes

## Bluetooth LE verification

PASSING uses Core Bluetooth only while a PASSING session is active. Please test with two physical iPhones:

1. Enable Bluetooth on both devices and launch PASSING.
2. Grant Bluetooth and location access when prompted.
3. On each device, choose a song and tap `PASSING開始`.
4. Keep the devices within a few meters for several seconds.
5. The PASSING screen displays `Bluetooth LEで近くのPASSINGを探しています` and the nearby count increases when the exchange completes.
6. The other device's song appears in the encounter list. Tap `PASSINGを終了` to save the memory.

The app does not exchange profiles or personal information. It exchanges the selected song payload anonymously over the Core Bluetooth GATT service while the user has explicitly started PASSING.
