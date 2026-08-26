# Pine64 Rockpro64

https://pine64.org/documentation/ROCKPro64

## Firmware

https://github.com/tomfitzhenry/row-boot

## Remote control

### UART

* GND: 6
* TX: 8
* RX: 10

https://pine64.org/documentation/ROCKPro64/Board/GPIOs/

### Power

CON16 has PWR and RST pins.

https://pine64.org/documentation/ROCKPro64/Board/Layout/

### Boot method

Default order: SPI, eMMC, SD, maskrom.

To disable SPI, drive pin 23 low.
To disable eMMC, use SW4.
To enter maskrom, press the recovery button.

https://pine64.org/documentation/ROCKPro64/Board/Layout/
