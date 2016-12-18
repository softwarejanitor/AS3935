/*
  AS3935.h - AS3935 Franklin Lightning Sensor™ IC by AMS library
  Copyright (c) 2012 Raivis Rengelis (raivis [at] rrkb.lv). All rights reserved.
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 3 of the License, or (at your option) any later version.
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

  Ported to Esquilo 20161217 Leeland Heins
*/

// register access macros - register address, bitmask
const AS3935_AFE_GB = 0x00;
const AS3935_AFE_GB_BM = 0x3E;
const AS3935_PWD = 0x00;
const AS3935_PWD_BM = 0x01;
const AS3935_NF_LEV = 0x01;
const AS3935_NF_LEV_BM = 0x70;
const AS3935_WDTH = 0x01;
const AS3935_WDTH_BM = 0x0F;
const AS3935_CL_STAT = 0x02;
const AS3935_CL_STAT_BM = 0x40;
const AS3935_MIN_NUM_LIGH = 0x02;
const AS3935_MIN_NUM_LIGH_BM = 0x30;
const AS3935_SREJ = 0x02;
const AS3935_SREJ_BM = 0x0F;
const AS3935_LCO_FDIV = 0x03;
const AS3935_LCO_FDIV_BM = 0xC0;
const AS3935_MASK_DIST = 0x03;
const AS3935_MASK_DIST_BM = 0x20;
const AS3935_INT = 0x03;
const AS3935_INT_BM = 0x0F;
const AS3935_DISTANCE = 0x07;
const AS3935_DISTANCE_BM = 0x1F;
const AS3935_DISP_LCO = 0x08;
const AS3935_DISP_LCO_BM = 0x80;
const AS3935_DISP_SRCO = 0x08;
const AS3935_DISP_SRCO_BM = 0x40;
const AS3935_DISP_TRCO = 0x08;
const AS3935_DISP_TRCO_BM = 0x20;
const AS3935_TUN_CAP = 0x08;
const AS3935_TUN_CAP_BM = 0x0F;

// other constants
const AS3935_AFE_INDOOR = 0x12
const AS3935_AFE_OUTDOOR = 0x0E

class AS3935
{
    i2c = null;
    addr = 0;
    irq = 0;

    constructor (_i2c, _addr, _irq)
    {
         i2c = _i2c;
         addr = _addr;
         irq = GPIO(_irq);
         irq.input();
    }
}

function AS3935::_ffsz(mask)
{
    local i = 0;
    if (mask) {
        for (i = 1; ~mask & 1; i++) {
            mask >>= 1;
        }
    }
    return i;
}

function AS3935::registerWrite(reg, mask, data)
{
    local regval;
    local writeBlob = blob(2);
    local readBlob = blob(1);

    print("regW " + regA + " " + mask + " " + data + " read ");

    i2c.address(addr);
    // read 1 byte
    writeBlob[0] = reg;
    writeBlob[1] = 0x01;
    i2c.xfer(writeBlob, readBlob);
    // put it to regval
    regval = readBlob[0];
    print(regval);
    // do masking
    regval &= ~(mask);
    if (mask) {
        regval |= (data << (_ffsz(mask) - 1));
    } else {
        regval |= data;
    }
    print(" write " + regval + " err ");
    // write the register back
    writeBlob[1] = regval;
    i2c.write(writeBlob);
}

function AS3935::registerRead(reg, mask)
{
    local regval;
    local writeBlob = blob(2);
    local readBlob = blob(1);

    i2c.address(addr);
    // read 1 byte
    writeBlob[0] = reg;
    writeBlob[1] = 0x01;
    i2c.xfer(writeBlob, readBlob);
    // put it to regval
    regval = readBlob[0];
    // mask
    regval = regval & mask;
    if (mask) {
        regval >>= (_ffsz(mask) - 1);
    }
    return regval;
}

function AS3935::reset()
{
    local writeBlob = blob(2);
    writeBlob[0] = 0x3c;
    writeBlob[1] = 0x96;
    // write to 0x3c, value 0x96
    i2c.address(addr);
    i2c.write(writeBlob);
    delay(2);
}

function AS3935::calibrate()
{
    local target = 3125;
    local currentcount = 0;
    local bestdiff = INT_MAX;
    local currdiff = 0;
    local bestTune = 0;
    local currTune = 0;
    local setUpTime;
    local currIrq;
    local prevIrq;
    local writeBlob = blob(2);
    // set lco_fdiv divider to 0, which translates to 16
    // so we are looking for 31250Hz on irq pin
    // and since we are counting for 100ms that translates to number 3125
    // each capacitor changes second least significant digit
    // using this timing so this is probably the best way to go
    registerWrite(AS3935_LCO_FDIV, AS3935_LCO_FDIV_BM, 0);
    registerWrite(AS3935_DISP_LCO, AS3935_DISP_LCO_BM, 1);
    // tuning is not linear, can't do any shortcuts here
    // going over all built-in cap values and finding the best
    for (currTune = 0; currTune <= 0x0F; currTune++)
    {
        registerWrite(AS3935_TUN_CAP, AS3935_TUN_CAP_BM, currTune);
        // let it settle
        delay(2);
        currentcount = 0;
        prevIrq = irq.ishigh();
        setUpTime = millis() + 100;
        while ((millis() - setUpTime) < 0) {
            currIrq = irq.ishigh();
            if (currIrq > prevIrq) {
                currentcount++;
            }
            prevIrq = currIrq;
        }
        currdiff = target - currentcount;
        // don't look at me, abs() misbehaves
        if (currdiff < 0) {
            currdiff = -currdiff;
        }
        if (bestdiff > currdiff) {
            bestdiff = currdiff;
            bestTune = currTune;
        }
    }
    registerWrite(AS3935_TUN_CAP, AS3935_TUN_CAP_BM, bestTune);
    delay(2);
    registerWrite(AS3935_DISP_LCO, AS3935_DISP_LCO_BM, 0);
    // and now do RCO calibration
    writeBlob[0] = 0x3d;
    writeBlob[1] = 0x96;
    i2c.write(writeBlob);
    delay(3);
    // if error is over 109, we are outside allowed tuning range of +/-3.5%
    print("Difference " + bestdiff + "\n");
    return bestdiff > 109 ? false : true;
}

function AS3935::powerDown()
{
    registerWrite(AS3935_PWD, AS3935_PWD_BM, 1);
}

function AS3935::powerUp()
{
    registerWrite(AS3935_PWD, AS3935_PWD_BM, 0);
    i2c.address(addr);
    local writeBlob = blob(2);
    writeBlob[0] = 0x3D;
    writeBlob[1] = 0x96;
    i2c.write(writeBlob);
    delay(3);
}

function AS3935::interruptSource()
{
    return registerRead(AS3935_INT, AS3935_INT_BM);
}

function AS3935::disableDisturbers()
{
    registerWrite(AS3935_MASK_DIST, AS3935_MASK_DIST_BM, 1);
}

function AS3935::enableDisturbers()
{
    registerWrite(AS3935_MASK_DIST, AS3935_MASK_DIST_BM, 0);
}

function AS3935::getMinimumLightnings()
{
    return registerRead(AS3935_MIN_NUM_LIGH, AS3935_MIN_NUM_LIGH_BM);
}

function AS3935::setMinimumLightnings(minlightning)
{
    registerWrite(AS3935_MIN_NUM_LIGH, AS3935_MIN_NUM_LIGH_BM, minlightning);
    return getMinimumLightnings();
}

function AS3935::lightningDistanceKm()
{
    return registerRead(AS3935_DISTANCE, AS3935_DISTANCE_BM);
}

function AS3935::setIndoors()
{
    registerWrite(AS3935_AFE_GB, AS3935_AFE_GB_BM, AS3935_AFE_INDOOR);
}

function AS3935::setOutdoors()
{
    registerWrite(AS3935_AFE_GB, AS3935_AFE_GB_BM, AS3935_AFE_OUTDOOR);
}

function AS3935::getNoiseFloor()
{
    return registerRead(AS3935_NF_LEV, AS3935_NF_LEV_BM);
}

function AS3935::setNoiseFloor(noisefloor)
{
    registerWrite(AS3935_NF_LEV, AS3935_NF_LEV_BM, noisefloor);
    return getNoiseFloor();
}

function AS3935::getSpikeRejection()
{
    return registerRead(AS3935_SREJ, AS3935_SREJ_BM);
}

function AS3935::setSpikeRejection(srej)
{
    registerWrite(AS3935_SREJ, AS3935_SREJ_BM, srej);
    return getSpikeRejection();
}

function AS3935::getWatchdogThreshold()
{
    return registerRead(AS3935_WDTH, AS3935_WDTH_BM);
}

function AS3935::setWatchdogThreshold(wdth)
{
    registerWrite(AS3935_WDTH, AS3935_WDTH_BM, wdth);
    return getWatchdogThreshold();
}

function AS3935::clearStats()
{
    registerWrite(AS3935_CL_STAT, AS3935_CL_STAT_BM, 1);
    registerWrite(AS3935_CL_STAT, AS3935_CL_STAT_BM, 0);
    registerWrite(AS3935_CL_STAT, AS3935_CL_STAT_BM, 1);
}

