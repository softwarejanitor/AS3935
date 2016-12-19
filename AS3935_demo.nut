require(["I2C", "GPIO"]);

// Create an I2C instance
i2c <- I2C(0);

// Load the library.
dofile("sd:/AS3935.nut");

delay(2);

// defines for hardware config
const define SI_PIN = 9;
const IRQ_PIN = 2;  // digital pins 2 and 3 are available for interrupt capability
const AS3935_ADD = 0x03;  // x03 - standard PWF SEN-39001-R01 config
const AS3935_CAPACITANCE = 72;  // <-- SET THIS VALUE TO THE NUMBER LISTED ON YOUR BOARD

// defines for general chip settings
const AS3935_INDOORS = 0;
const AS3935_OUTDOORS = 1;
const AS3935_DIST_DIS = 0;
const AS3935_DIST_EN = 1;

print("Playing With Fusion: AS3935 Lightning Sensor\n");
print("beginning boot procedure....\n");

// Instantiate the object
local lightning0 = AS3935(i2c, AS3935_ADD, IRQ_PIN);

local AS3935_ISR_Trig = 0;  // clear trigger

// setup for the the I2C library: (enable pullups, set speed to 400kHz)

lightning0.AS3935_DefInit();   // set registers to default
// now update sensor cal for your application and power up chip
lightning0.AS3935_ManualCal(AS3935_CAPACITANCE, AS3935_OUTDOORS, AS3935_DIST_EN);
                            // AS3935_ManualCal Parameters:
                            //   --> capacitance, in pF (marked on package)
                            //   --> indoors/outdoors (AS3935_INDOORS:0 / AS3935_OUTDOORS:1)
                            //   --> disturbers (AS3935_DIST_EN:1 / AS3935_DIST_DIS:2)
                            // function also powers up the chip

// enable interrupt (hook IRQ pin to Esquilo interrupt input: 0 -> pin 2, 1 -> pin 3)
lightning0.irq.onrising(
    function AS3935_ISR()
    {
        // this is irq handler for AS3935 interrupts, has to return void and take no arguments
        // always make code in interrupt handlers fast and short
        AS3935_ISR_Trig = 1;
    }
);

lightning0.AS3935_PrintAllRegs();


while (1) {
    // This program only handles an AS3935 lightning sensor. It does nothing until
    // an interrupt is detected on the IRQ pin.
    while (0 == AS3935_ISR_Trig) {
        delay(1);
    }
    delay(5);

    // reset interrupt flag
    AS3935_ISR_Trig = 0;

    // now get interrupt source
    int_src = lightning0.AS3935_GetInterruptSrc();
    if (0 == int_src) {
        print("interrupt source result not expected\n");
    } else if (1 == int_src) {
        local lightning_dist_km = lightning0.AS3935_GetLightningDistKm();
        print("Lightning detected! Distance to strike: " + lightning_dist_km + " kilometers\n");
    } else if (2 == int_src) {
        print("Disturber detected\n");
    } else if (3 == int_src) {
        print("Noise level too high\n");
    }
    lightning0.AS3935_PrintAllRegs();  // for debug...
}

