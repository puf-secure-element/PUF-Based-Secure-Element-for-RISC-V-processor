module apb_decoder (// APB interface
                    input wire pclk, 
                    input wire presetn,
                    input wire [9:0]  paddr, 
                    input wire        psel, 
                    input wire        penable, 
                    input wire        pwrite, 
                    input wire [31:0] pwdata,
                    output wire       pready, 
                    output reg [31:0] prdata, 
                    output wire       pslverr,
                    
                    // Divisor setting
                    output wire       osm_sel,
                    output wire [7:0] dll,
                    output wire [7:0] dlh,
                    
                    // UART setting
                    output wire       bge,
                    output wire       eps,
                    output wire       pen,
                    output wire       stb,
                    output wire [1:0] wls,
            
                    // Enable Hard Interrupt
                    output wire en_tx_fifo_full,
                    output wire en_tx_fifo_empty,
                    output wire en_rx_fifo_full,
                    output wire en_rx_fifo_empty,
                    output wire en_parrity_error,

                    // Parity error
                    input  wire s_parrity_error,
                    output reg  parrity_error_status,

                    // TX FIFO
                    input  wire       tx_full_status,
                    input  wire       tx_empty_status,
                    output reg        tx_wr,
                    output wire [7:0] tx_data,

                    //RX FIFO
                    input  wire       rx_full_status,
                    input  wire       rx_empty_status,
                    input  wire [7:0] rx_data,
                    output reg        rx_rd
                    );

  // Internal signal
  wire apb_wr_en;
  wire apb_rd_en;
  reg[9:0] reg_sel;
  
  // Register
  reg[7:0] reg_mdr;
  reg[7:0] reg_dll;
  reg[7:0] reg_dlh;
  reg[7:0] reg_lcr;
  reg[7:0] reg_ier;
  reg[7:0] reg_fsr;
  reg[7:0] reg_tbr;
  reg[7:0] reg_rbr;
  
  //
  assign osm_sel = reg_mdr[0];
  assign dll     = reg_dll;
  assign dlh     = reg_dlh;
  assign bge     = reg_lcr[5];
  assign eps     = reg_lcr[4];
  assign pen     = reg_lcr[3];
  assign stb     = reg_lcr[2];
  assign wls     = reg_lcr[1:0];
  assign tx_data = reg_tbr;
  assign en_parrity_error = reg_ier[4];
  assign en_rx_fifo_empty = reg_ier[3];
  assign en_rx_fifo_full  = reg_ier[2];
  assign en_tx_fifo_empty = reg_ier[1];
  assign en_tx_fifo_full  = reg_ier[0];

  // Indicate APB WRITE or READ
  assign apb_wr_en = pwrite & psel & penable;
  assign apb_rd_en = ~pwrite & psel & penable;
  
  assign pslverr = (reg_sel[8] & (apb_wr_en | apb_rd_en))? 1 : 0;
  assign pready  = 1'b1;

  // Decode address
  always @(psel or paddr) 
    begin
      if(psel)
        case(paddr)
          10'h100: reg_sel = 9'b0_0000_0001; // MDR
          10'h104: reg_sel = 9'b0_0000_0010; // DLL
          10'h108: reg_sel = 9'b0_0000_0100; // DLH
          10'h10C: reg_sel = 9'b0_0000_1000; // LCR 
          10'h110: reg_sel = 9'b0_0001_0000; // IER
          10'h114: reg_sel = 9'b0_0010_0000; // FSR
          10'h118: reg_sel = 9'b0_0100_0000; // TBR
          10'h11C: reg_sel = 9'b0_1000_0000; // RBR
          default: reg_sel = 9'b1_0000_0000;  // rsvd
        endcase
      else
        reg_sel = 9'b0_0000_0000;
    end
  
  // Register MRD
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_mdr <= 8'h00;
      else if(apb_wr_en && reg_sel[0])
        reg_mdr[0] <= pwdata[0];
      else 
        reg_mdr <= reg_mdr;
    end

  // Register DLL
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_dll <= 8'h00;
      else if(apb_wr_en && reg_sel[1])
        reg_dll <= pwdata;
      else 
        reg_dll <= reg_dll;
    end  
  
  // Register DLH
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_dlh <= 8'h00;
      else if(apb_wr_en && reg_sel[2])
        reg_dlh <= pwdata;
      else 
        reg_dlh <= reg_dlh;
    end  
  
  // Register LCR
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_lcr <= 8'h03;
      else if(apb_wr_en && reg_sel[3])
        reg_lcr <= pwdata[5:0];
      else 
        reg_lcr <= reg_lcr;
    end  
  
  // Register IER
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_ier <= 8'h00;
      else if(apb_wr_en && reg_sel[4])
        reg_ier <= pwdata[4:0];
      else 
        reg_ier <= reg_ier;
    end 

  // Register FSR - reg_sel[5]
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_fsr <= 8'h0A;
      else 
        reg_fsr <= reg_fsr;
    end  
  
  // Register TBR- reg_sel[6]
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_tbr <= 8'h00;
      else if(apb_wr_en && reg_sel[6])
        reg_tbr <= pwdata;
      else 
        reg_tbr <= reg_tbr;
    end 
  
  // Register RBR - reg_sel[7]
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        reg_rbr <= 8'h00;
      else 
        reg_rbr <= reg_rbr;
    end 

  // Return PRDATA
  always @(psel or paddr or pready or penable) 
    begin
      if(apb_rd_en && pready)
        case(paddr)
          10'h100: prdata = reg_mdr;        // MDR
          10'h104: prdata = reg_dll;        // DLL
          10'h108: prdata = reg_dlh;        // DLH
          10'h10C: prdata = reg_lcr;        // LCR
          10'h110: prdata = reg_ier;        // IER
          10'h114: prdata = {27'h0,parrity_error_status,rx_empty_status,rx_full_status,tx_empty_status,tx_full_status}; // FSR
          10'h118: prdata = 32'h0000_0000;  // TBR
          10'h11C: prdata = rx_data;        // RBR
          default: prdata = 32'hFFFF_FFFF;  // rsvd
        endcase
      else 
        prdata = 8'h00;
    end
  
  // Check parity error, Read-Write 1 to clear
  always @(posedge pclk or negedge presetn)
  begin
    if(!presetn)
      parrity_error_status <= 1'b0;
    else if(s_parrity_error)
      parrity_error_status <= 1'b1;
    else if(reg_sel[5] && apb_wr_en) begin
      if(pwdata[4] == 1)
        parrity_error_status <= 1'b0;
      else
        parrity_error_status <= parrity_error_status;
    end
  end
 
  // Send data to TX FIFO
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        tx_wr <= 1'b0;
      else if(~tx_full_status & pready & apb_wr_en & reg_sel[6])
        tx_wr <= 1'b1;
      else 
        tx_wr <= 1'b0;
    end 
  
  // Get data from RX FIFO
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        rx_rd <= 1'b0;
      else if(~rx_empty_status & pready & apb_rd_en & reg_sel[7])
        rx_rd <= 1'b1;
      else
        rx_rd <= 1'b0;
    end

endmodule

