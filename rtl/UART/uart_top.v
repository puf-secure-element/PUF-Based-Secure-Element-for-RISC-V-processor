module uart_top (//AHB interface
                 input wire HCLK, 
                 input wire HRESETN,
                 input wire [9:0]   HADDR, 
                 input wire [1:0]   HTRANS, 
                 input wire [2:0]   HBURST, 
                 input wire [2:0]   HSIZE, 
                 input wire [3:0]   HPROT, 
                 input wire         HWRITE, 
                 input wire         HSEL, 
                 input wire [31:0]  HWDATA,
                 output wire        HREADYOUT, 
                 output wire [31:0] HRDATA, 
                 output wire        HRESP,

                 //UART interface
                 input wire uart_rxd,
                 output wire uart_txd,
                 
                 //Interrupt
                 output wire interrupt
                );
  
  wire       bclk;
  wire       osm_sel;
  wire [7:0] dll;
  wire [7:0] dlh;
  wire       bge;
  wire       eps;
  wire       pen;
  wire       stb;
  wire [1:0] wls;
 
  wire tx_wr;
  wire tx_rd;
  wire [7:0] tx_data_in;
  wire [7:0] tx_data_out;
  wire tx_full_status; 
  wire tx_empty_status;

  wire rx_rd;
  wire rx_wr;
  wire [7:0] rx_data_out;
  wire [7:0] rx_data_in;
  wire rx_full_status;
  wire rx_empty_status;

  wire en_tx_fifo_full;
  wire en_tx_fifo_empty;
  wire en_rx_fifo_full;
  wire en_rx_fifo_empty;
  
  wire[9:0]   paddr;
  wire[31:0]  pwdata;
  wire[31:0]  prdata;

  cmsdk_ahb_to_apb #(.ADDRWIDTH(10)) 
  u_bridge(.HCLK(HCLK),      
             .HRESETn(HRESETN),   
             .PCLKEN(1'b1),    
             .HSEL(HSEL),      
             .HADDR(HADDR),     
             .HTRANS(HTRANS),    
             .HSIZE(HSIZE),     
             .HPROT(HPROT),     
             .HWRITE(HWRITE),    
             .HREADY(1'b1),    
             .HWDATA(HWDATA),    
             .HREADYOUT(HREADYOUT), 
             .HRDATA(HRDATA),    
             .HRESP(HRESP),     
             .PADDR(paddr),     
             .PENABLE(penable),   
             .PWRITE(pwrite),    
             .PSTRB(),  // float 
             .PPROT(),  // float   
             .PWDATA(pwdata),    
             .PSEL(psel),      
             .APBACTIVE(), // float
             .PRDATA(prdata),    
             .PREADY(pready),    
             .PSLVERR(pslverr));  

  apb_decoder u_apb(.pclk(HCLK),
                  .presetn(HRESETN),
                  .paddr(paddr),
                  .psel(psel),
                  .penable(penable),
                  .pwrite(pwrite),
                  .pwdata(pwdata),
                  .pready(pready),
                  .prdata(prdata),
                  .pslverr(pslverr),
                  .osm_sel(osm_sel),
                  .dll(dll),
                  .dlh(dlh),
                  .bge(bge),
                  .eps(eps),
                  .pen(pen),
                  .stb(stb),
                  .wls(wls),
                  .en_tx_fifo_full(en_tx_fifo_full),
                  .en_tx_fifo_empty(en_tx_fifo_empty),
                  .en_rx_fifo_full(en_rx_fifo_full),
                  .en_rx_fifo_empty(en_rx_fifo_empty),
                  .en_parrity_error(en_parrity_error),
                  .s_parrity_error(s_parrity_error),
                  .parrity_error_status(parrity_error_status),
                  .tx_full_status(tx_full_status),
                  .tx_empty_status(tx_empty_status),
                  .tx_wr(tx_wr),
                  .tx_data(tx_data_in),
                  .rx_full_status(rx_full_status),
                  .rx_empty_status(rx_empty_status),
                  .rx_rd(rx_rd),
                  .rx_data(rx_data_out));

  uart_fifo u_tx_fifo (.pclk(HCLK),
                       .presetn(HRESETN),
                       .wr(tx_wr),
                       .rd(tx_rd),
                       .data_in(tx_data_in),
                       .data_out(tx_data_out),
                       .fifo_full(tx_full_status),
                       .fifo_empty(tx_empty_status));

  uart_fifo u_rx_fifo (.pclk(HCLK),
                       .presetn(HRESETN),
                       .wr(rx_wr),
                       .rd(rx_rd),
                       .data_in(rx_data_in),
                       .data_out(rx_data_out),
                       .fifo_full(rx_full_status),
                       .fifo_empty(rx_empty_status));

  uart_transmitter u_uart_tx(.pclk(HCLK),
                             .presetn(HRESETN),
                             .bclk(bclk),
                             .tx_data(tx_data_out),
                             .tx_empty_status(tx_empty_status),
                             .tx_rd(tx_rd),
                             .osm_sel(osm_sel),
                             .eps(eps),
                             .pen(pen),
                             .stb(stb),
                             .wls(wls),
                             .uart_txd(uart_txd));
  
  uart_receiver u_uart_rx(.pclk(HCLK),
                          .presetn(HRESETN),
                          .bclk(bclk),
                          .rx_data(rx_data_in),
                          .rx_full_status(rx_full_status),
                          .rx_wr(rx_wr),
                          .osm_sel(osm_sel),
                          .eps(eps),
                          .pen(pen),
                          .stb(stb),
                          .wls(wls),
                          .s_parrity_error(s_parrity_error),
                          .uart_rxd(uart_rxd));

  uart_interrupt u_uart_intr (.tx_fifo_full(tx_fifo_full),
                              .tx_fifo_empty(tx_fifo_empty),
                              .rx_fifo_full(rx_fifo_full),
                              .rx_fifo_empty(rx_fifo_empty),
                              .parrity_error(parrity_error),
                              .en_tx_fifo_full(en_tx_fifo_full),
                              .en_tx_fifo_empty(en_tx_fifo_empty),
                              .en_rx_fifo_full(en_rx_fifo_full),
                              .en_rx_fifo_empty(en_rx_fifo_empty),
                              .en_parrity_error(en_parrity_error),
                              .tx_full_status(tx_full_status),
                              .tx_empty_status(tx_empty_status),
                              .rx_full_status(rx_full_status),
                              .rx_empty_status(rx_empty_status),
                              .parrity_error_status(parrity_error_status));

  baud_generator u_baud_gen(.clk(HCLK),
                            .resetn(HRESETN),
                            .enable(bge),
                            .divisor({dlh,dll}),
                            .bclk(bclk));

  assign interrupt = tx_fifo_full | tx_fifo_empty | rx_fifo_full | rx_fifo_empty | parrity_error;
endmodule                          


