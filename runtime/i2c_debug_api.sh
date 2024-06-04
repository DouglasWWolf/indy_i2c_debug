#==============================================================================
#  Date      Vers   Who  Description
# -----------------------------------------------------------------------------
# 04-Jun-24  1.0.0  DWW  Initial Creation
#==============================================================================
I2C_DEBUG_API_VERSION=1.0.0
#==============================================================================

BASE_ADDR=0x1000
       REG_IDLE=$((BASE_ADDR + 0 * 4))
REG_MUX_CHANNEL=$((BASE_ADDR + 1 * 4))
 REG_I2C_STATUS=$((BASE_ADDR + 2 * 4))  
   REG_DEV_ADDR=$((BASE_ADDR + 3 * 4))    
       REG_READ=$((BASE_ADDR + 4 * 4))        
    REG_RX_DATA=$((BASE_ADDR + 5 * 4))

#==============================================================================
# This reads a PCI register and displays its value in decimal
#==============================================================================
read_reg()
{
    pcireg -dec $1
}
#==============================================================================


#==============================================================================
# Displays '1' if the system is idle, otherwise displays 0
#==============================================================================
is_idle()
{
    read_reg $REG_IDLE
}
#==============================================================================



#==============================================================================
# Waits until the system is idle
#==============================================================================
wait_idle()
{
    while [ $(read_reg $REG_IDLE) -eq 0 ]; do
        sleep .001
    done
}
#==============================================================================


#==============================================================================
# This instructs the system to return to idle mode
#==============================================================================
idle()
{
    pcireg $REG_IDLE 1
    wait_idle
}
#==============================================================================




#==============================================================================
# This changes the mux channel to the specified channel
#==============================================================================
mux()
{
    local channel=$1

    # If the user didn't give us a mux channel, just display it
    if [ "$channel" == "" ]; then
        read_reg $REG_MUX_CHANNEL
        return
    fi

    # Make sure the channel number is valid
    if [ $channel -lt 0 ] || [ $channel -gt 3 ]; then
        echo "Illegal channel number" 1>&2
    fi

    # Force the system into idle mode
    idle

    # Set the I2C mux to the specified channel
    pcireg $REG_MUX_CHANNEL $channel

    # Wait for the system to go idle again
    wait_idle
}
#==============================================================================


#==============================================================================
# Reads 4 bytes from the specified device and register number
#==============================================================================
read()
{

    # Make sure the user gave us a device address
    if [ "$1" == "" ]; then
        echo "Missing device address on read" 1>&2
        return
    fi

    # Make sure the user gave us a register number
    if [ "$2" == "" ]; then
        echo "Missing register number number on read" 1>&2
        return
    fi

    # Convert both the device address and register to numbers
    local device=$(($1))
    local regnum=$(($2))

    # User isn't allowed to read the I2C mux
    if [ $device -eq $((0x70)) ]; then
        echo "Reading device 0x70 is not allowed" 1>&2
        return
    fi

    # Make sure there is a currently selected mux channel
    if [ $(read_reg $REG_MUX_CHANNEL) -gt 7 ]; then
        echo "Mux channel has not yet been selected" 1>&2
        return
    fi

    # Make the system idle
    idle

    # Set the device address we're going to read from
    pcireg $REG_DEV_ADDR $device

    # Read the specified register from the specified device
    pcireg $REG_READ $regnum

    # Wait plenty of time for a read-request to complete
    sleep .1

    # Fetch the status of the I2C transaction
    local status=$(read_reg $REG_I2C_STATUS)

    # Check for a bus fault
    if [ $status == 3 ]; then
        printf "Bus fault while reading device address 0x%02X\n" $device
        return
    fi

    # Check for a timeout
    if [ $status == 5 ]; then
        printf "Timeout while reading device address 0x%02X\n" $device
        return
    fi

    # If we get here, display the result
    pcireg -hex $REG_RX_DATA

}
#==============================================================================