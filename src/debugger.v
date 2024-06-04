//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 03-Jun-24  DWW     1  Initial creation
//====================================================================================

/*
    This is a debugger for the QSFP-related I2C bus on an Indy board
*/


module debugger # (parameter FREQ_HZ = 250000000)
(

    input clk, resetn,

    // The state of our "command" state-machine
    output reg[7:0] csm_state,

    // These have to be configured properly to talk the management interface
    // of a QSFP transceiver module.
    output[1:0] QSFP_MODSEL_L, QSFP_RESET_L, QSFP_LP,

    // We use this to reset the mux at the front of the I2C bus
    output reg I2C_MUX_ENABLE,

    output reg       I2C_CONFIG,
    output reg[ 6:0] I2C_DEV_ADDR,
    output reg[ 1:0] I2C_REG_NUM_LEN,
    output reg[15:0] I2C_REG_NUM,
    output reg[ 2:0] I2C_READ_LEN,
    output reg       I2C_READ_START,
    output reg[31:0] I2C_TX_DATA,
    output reg[ 2:0] I2C_WRITE_LEN,
    output reg       I2C_WRITE_START,
    output reg[31:0] I2C_TLIMIT_USEC,

    input     [31:0] I2C_RX_DATA,
    input     [ 7:0] I2C_STATUS,
    input            I2C_IDLE,

    // We don't use these
    output reg       PASSTHRU,
    output reg[31:0] PASSTHRU_WDATA,
    output reg[11:0] PASSTHRU_ADDR,
    output reg       PASSTHRU_wstrobe,
    
    //================== This is an AXI4-Lite slave interface ==================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY
    //==========================================================================
);  

// Configure the QSFP modules to be alive and talking to us
assign QSFP_LP       = 0;
assign QSFP_MODSEL_L = 0;
assign QSFP_RESET_L  = 3;

//=========================  AXI Register Map  =============================
localparam REG_IDLE         = 0;
localparam REG_MUX_CHANNEL  = 1;
localparam REG_I2C_STATUS   = 2;
localparam REG_DEV_ADDR     = 3;
localparam REG_READ         = 4;
localparam REG_RX_DATA      = 5;
//==========================================================================


//==========================================================================
// We'll communicate with the AXI4-Lite Slave core with these signals.
//==========================================================================
// AXI Slave Handler Interface for write requests
wire[31:0]  ashi_windx;     // Input   Write register-index
wire[31:0]  ashi_waddr;     // Input:  Write-address
wire[31:0]  ashi_wdata;     // Input:  Write-data
wire        ashi_write;     // Input:  1 = Handle a write request
reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
wire        ashi_widle;     // Output: 1 = Write state machine is idle

// AXI Slave Handler Interface for read requests
wire[31:0]  ashi_rindx;     // Input   Read register-index
wire[31:0]  ashi_raddr;     // Input:  Read-address
wire        ashi_read;      // Input:  1 = Handle a read request
reg[31:0]   ashi_rdata;     // Output: Read data
reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
wire        ashi_ridle;     // Output: 1 = Read state machine is idle
//==========================================================================

// The state of the state-machines that handle AXI4-Lite read and AXI4-Lite write
reg ashi_write_state, ashi_read_state;

// The AXI4 slave state machines are idle when in state 0 and their "start" signals are low
assign ashi_widle = (ashi_write == 0) && (ashi_write_state == 0);
assign ashi_ridle = (ashi_read  == 0) && (ashi_read_state  == 0);
   
// These are the valid values for ashi_rresp and ashi_wresp
localparam OKAY   = 0;
localparam SLVERR = 2;
localparam DECERR = 3;

// This is the I2C address of the I2C mux
localparam MUX_ADDR = 7'h70;

// The number of clock-cycles in a millisecond
localparam MILLISECOND = FREQ_HZ / 1000;

// An AXI slave is gauranteed a minimum of 128 bytes of address space
// (128 bytes is 32 32-bit registers)
localparam ADDR_MASK = 7'h7F;

// This is the channel number that will be used during the next SET_MUX command
// This is intentionally 1-bit too wide because we use that bit to signal that
// "mux_channel" hasn't yet been initialized
reg[3:0] mux_channel;

// States for our "COMMAND" state machine
localparam CSM_SET_MUX = 10;
localparam CSM_READ    = 20;

// This contains the command to carry out
reg[1:0] command;
localparam CMD_SET_MUX = 1;
localparam CMD_READ    = 2;

// This is the status of the most recent I2C transaction
reg[2:0] transaction_status;

// This is the data read via an I2C read operation
reg[31:0] i2c_rx_data;

// The device address we want to read
reg[6:0] i2c_dev_addr;

// The device register number we want to read
reg[7:0] i2c_reg_num;

//==========================================================================
// This is the "command" state machine that carries out commands
//==========================================================================
reg[31:0] delay;
reg halt, latched_halt;
//--------------------------------------------------------------------------
always @(posedge clk) begin

    // These strobes high for one clock cycle at a time
    I2C_WRITE_START <= 0;
    I2C_READ_START  <= 0;

    // This is a delay timer that continuously counts down to 0
    if (delay) delay <= delay - 1;

    // If we see a "halt" signal, latch it
    if (halt) latched_halt <= 1;

    if (resetn == 0) begin
        csm_state      <= 0;
        latched_halt   <= 0;
        I2C_MUX_ENABLE <= 1;
    end else case (csm_state)

        // Wait for a command to occur
        0:  begin
                latched_halt <= 0;
                case (command)
                    CMD_SET_MUX: csm_state <= CSM_SET_MUX;
                    CMD_READ:    csm_state <= CSM_READ;
                    default:     csm_state <= 0;
                endcase
            end

        // Place the mux in reset and wait 5 milliseconds
        CSM_SET_MUX:
            begin
                I2C_MUX_ENABLE <= 0;
                delay          <= 5 * MILLISECOND;
                csm_state      <= csm_state + 1;
            end

        // Take the mux out of reset and wait 10 milliseconds
        CSM_SET_MUX + 1:
            if (delay == 0) begin
                I2C_MUX_ENABLE <= 1;
                delay          <= 10 * MILLISECOND;
                csm_state      <= csm_state + 1;
            end

        // Write the mux-channel to the I2C mux
        CSM_SET_MUX + 2:
            if (delay == 0) begin
                I2C_CONFIG      <= 0;
                I2C_DEV_ADDR    <= MUX_ADDR;
                I2C_REG_NUM_LEN <= 0;
                I2C_TLIMIT_USEC <= 5000;
                I2C_TX_DATA     <= (1 << mux_channel);
                I2C_WRITE_LEN   <= 1;
                I2C_WRITE_START <= 1;
                csm_state       <= csm_state + 1;
            end

        // Wait for the I2C engine to start
        CSM_SET_MUX + 3:
            if (I2C_IDLE == 0) begin
                csm_state <= csm_state + 1;
            end

        // When the I2C engine goes idle again, transaction is complete
        CSM_SET_MUX + 4:
            if (I2C_IDLE == 1) begin
                transaction_status <= I2C_STATUS;
                csm_state          <= 0;
            end
    
        // Start a read of 4-bytes from the selected I2C device
        CSM_READ:
            begin
                I2C_CONFIG      <= 0;
                I2C_DEV_ADDR    <= i2c_dev_addr;
                I2C_REG_NUM     <= i2c_reg_num;
                I2C_REG_NUM_LEN <= 1;
                I2C_TLIMIT_USEC <= 5000;
                I2C_READ_LEN    <= 4;
                I2C_READ_START  <= 1;
                csm_state       <= csm_state + 1;
            end

        // Wait for the I2C engine to start
        CSM_READ + 1:
            if (I2C_IDLE == 0) begin
                csm_state <= csm_state + 1;
            end

        // When the I2C engine goes idle, the transaction is complete
        CSM_READ + 2:
            if (I2C_IDLE == 1) begin
                transaction_status <= I2C_STATUS;
                i2c_rx_data        <= I2C_RX_DATA;
                delay              <= 100 * MILLISECOND;
                csm_state          <= csm_state + 1;
            end

        // Delay for a bit.  While that is happening, if we see
        // a "halt" signal, go back to idle
        CSM_READ + 3:
            if (latched_halt)
                csm_state <= 0;
            else if (delay == 0)
                csm_state <= CSM_READ;

    endcase

end
//==========================================================================




//==========================================================================
// This state machine handles AXI4-Lite write requests
//==========================================================================
always @(posedge clk) begin

    // These strobes high for one cycle at a time
    halt    <= 0;
    command <= 0;

    // If we're in reset, initialize important registers
    if (resetn == 0) begin
        ashi_write_state  <= 0;
        mux_channel       <= -1;

    // If we're not in reset, and a write-request has occured...        
    end else case (ashi_write_state)
        
        0:  if (ashi_write) begin
       
                // Assume for the moment that the result will be OKAY
                ashi_wresp <= OKAY;              
            
                // Convert the byte address into a register index
                case (ashi_windx)
               
                    REG_IDLE:
                        halt <= 1;
                    
                    REG_MUX_CHANNEL: 
                        begin
                            mux_channel <= ashi_wdata[2:0];
                            command     <= CMD_SET_MUX;
                        end

                    REG_DEV_ADDR:
                        i2c_dev_addr <= ashi_wdata;
                    
                    REG_READ:
                        begin
                            i2c_reg_num  <= ashi_wdata;
                            command      <= CMD_READ;
                        end


                    // Writes to any other register are a decode-error
                    default: ashi_wresp <= DECERR;
                endcase
            end

        // Dummy state, doesn't do anything
        1: ashi_write_state <= 0;

    endcase
end
//==========================================================================





//==========================================================================
// World's simplest state machine for handling AXI4-Lite read requests
//==========================================================================
always @(posedge clk) begin
    // If we're in reset, initialize important registers
    if (resetn == 0) begin
        ashi_read_state <= 0;
    
    // If we're not in reset, and a read-request has occured...        
    end else if (ashi_read) begin
   
        // Assume for the moment that the result will be OKAY
        ashi_rresp <= OKAY;              
        
        // Convert the byte address into a register index
        case (ashi_rindx)
            
            // Allow a read from any valid register                
            REG_IDLE       :   ashi_rdata <= (csm_state == 0) & (command == 0);
            REG_MUX_CHANNEL:   ashi_rdata <= mux_channel;
            REG_I2C_STATUS :   ashi_rdata <= transaction_status;
            REG_DEV_ADDR   :   ashi_rdata <= i2c_dev_addr;
            REG_RX_DATA    :   ashi_rdata <= i2c_rx_data;
          
            
            // Reads of any other register are a decode-error
            default: ashi_rresp <= DECERR;
        endcase
    end
end
//==========================================================================



//==========================================================================
// This connects us to an AXI4-Lite slave core
//==========================================================================
axi4_lite_slave#(ADDR_MASK) axil_slave
(
    .clk            (clk),
    .resetn         (resetn),
    
    // AXI AW channel
    .AXI_AWADDR     (S_AXI_AWADDR),
    .AXI_AWVALID    (S_AXI_AWVALID),   
    .AXI_AWREADY    (S_AXI_AWREADY),
    
    // AXI W channel
    .AXI_WDATA      (S_AXI_WDATA),
    .AXI_WVALID     (S_AXI_WVALID),
    .AXI_WSTRB      (S_AXI_WSTRB),
    .AXI_WREADY     (S_AXI_WREADY),

    // AXI B channel
    .AXI_BRESP      (S_AXI_BRESP),
    .AXI_BVALID     (S_AXI_BVALID),
    .AXI_BREADY     (S_AXI_BREADY),

    // AXI AR channel
    .AXI_ARADDR     (S_AXI_ARADDR), 
    .AXI_ARVALID    (S_AXI_ARVALID),
    .AXI_ARREADY    (S_AXI_ARREADY),

    // AXI R channel
    .AXI_RDATA      (S_AXI_RDATA),
    .AXI_RVALID     (S_AXI_RVALID),
    .AXI_RRESP      (S_AXI_RRESP),
    .AXI_RREADY     (S_AXI_RREADY),

    // ASHI write-request registers
    .ASHI_WADDR     (ashi_waddr),
    .ASHI_WINDX     (ashi_windx),
    .ASHI_WDATA     (ashi_wdata),
    .ASHI_WRITE     (ashi_write),
    .ASHI_WRESP     (ashi_wresp),
    .ASHI_WIDLE     (ashi_widle),

    // ASHI read registers
    .ASHI_RADDR     (ashi_raddr),
    .ASHI_RINDX     (ashi_rindx),
    .ASHI_RDATA     (ashi_rdata),
    .ASHI_READ      (ashi_read ),
    .ASHI_RRESP     (ashi_rresp),
    .ASHI_RIDLE     (ashi_ridle)
);
//==========================================================================

assign dbg_csm_state = csm_state;

endmodule
