module uart_receiver ( // CLK&RST
                       input wire pclk,
                       input wire presetn,
                       input wire bclk,
                       
                       // FIFO
                       output wire[7:0] rx_data,
                       input wire       rx_full_status,
                       output wire      rx_wr,

                       //UART setting
                       input wire        osm_sel,
                       input wire        eps,
                       input wire        pen,
                       input wire        stb,
                       input wire [1:0]  wls,
                      
                       // Parity error status
                       output reg s_parrity_error,
                       
                       // UART IF
                       input reg uart_rxd
                     );
`protect
  parameter IDLE    = 3'b000; 
  parameter START   = 3'b001;
  parameter RX_DATA = 3'b010;
  parameter PARITY  = 3'b011;
  parameter STOP    = 3'b100;
  reg[2:0] current_state;
  reg[2:0] next_state;
  reg[3:0] count;
  reg[3:0] data_cnt;
  reg[1:0] stop_cnt;
  reg[7:0] data_in;
  reg count_detect;
  reg sample_detect;
  wire data_sample_en;
  wire parity_sample_en;
  wire[3:0] osm_cnt;
  wire rx_data_complete;
  wire jump_state;
  wire stop_complete;
  wire start_end;
  wire data_end;
  wire parity_end;
  wire stop_end;
  wire start_detect;
 
  reg calculated_parity;
  // Send data to FIFO
  assign rx_data = (wls==2'b00) ? data_in[7:3] :
                   (wls==2'b01) ? data_in[7:2] :
                   (wls==2'b10) ? data_in[7:1] :
                   data_in;
  assign rx_wr = (stop_complete) & ~rx_full_status & stop_end;
  assign start_detect = (current_state == IDLE) & (uart_rxd == 1'b0);
  assign jump_state = count_detect & (count == 4'h0);
  assign data_sample_en   = (osm_cnt == 4'hf)? sample_detect & (count == 4'h8) & current_state == RX_DATA:
                                               sample_detect & (count == 4'h6) & current_state == RX_DATA;
  assign parity_sample_en = (osm_cnt == 4'hf)? sample_detect & (count == 4'h8) & current_state == PARITY:
                                               sample_detect & (count == 4'h6) & current_state == PARITY;
  assign start_end  = (current_state == START) & jump_state;
  assign data_end   = (current_state == RX_DATA) & (rx_data_complete) & jump_state;
  assign parity_end = (current_state == PARITY)  & jump_state;
  assign stop_end   = (current_state == STOP) & stop_complete & jump_state;
  assign rx_data_complete = (wls==2'b00) ? (data_cnt == 4'd5) :
                            (wls==2'b01) ? (data_cnt == 4'd6) :
                            (wls==2'b10) ? (data_cnt == 4'd7) :
                            (data_cnt == 4'd8);
  assign stop_complete = (stb==1'b0) ? (stop_cnt == 2'b01) : (stop_cnt == 2'b10);
  assign osm_cnt = (osm_sel)? 4'hc : 4'hf;
  
  // Fixed bug, fixed issue calculate parity in receive mode, revision 2.2
  always @(*) 
    begin
      if(eps) 
        case(wls)
          2'b00:  calculated_parity = ^rx_data[4:0];
          2'b01:  calculated_parity = ^rx_data[5:0];
          2'b10:  calculated_parity = ^rx_data[6:0];
          default:calculated_parity = ^rx_data[7:0];
        endcase
      else
        case(wls)
          2'b00:  calculated_parity = ~(^rx_data[4:0]);
          2'b01:  calculated_parity = ~(^rx_data[5:0]);
          2'b10:  calculated_parity = ~(^rx_data[6:0]);
          default:calculated_parity = ~(^rx_data[7:0]);
        endcase
    end

  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        s_parrity_error <= 1'b0;
      else if(current_state == PARITY && parity_sample_en)
        s_parrity_error <= (calculated_parity != uart_rxd);
      else
        s_parrity_error <= 1'b0;

    end 

  // Enable shift bit
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        sample_detect <= 0;
      else if(current_state == RX_DATA || current_state == PARITY) // Add current_state == PARITY to fixed issue 
        case(osm_cnt)
          4'hc:begin
            if(count == 4'h5) 
              sample_detect <= 1'b1;
            else 
              sample_detect <= 1'b0;
          end
          4'hf: begin
            if(count == 4'h7) 
              sample_detect <= 1'b1;
            else 
              sample_detect <= 1'b0;
          end
        endcase
      else 
        sample_detect <= 0;
    end

  // Store bit temp register
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        data_in <= 8'h00;
      else if(data_sample_en)
        data_in <= {uart_rxd,data_in[7:1]};
      else
        data_in <= data_in;
    end
  
  // Total data will be shift in DATA state
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        data_cnt <= 5'h0;
      else if(current_state == RX_DATA)
        if((count == osm_cnt) & bclk)
          data_cnt <= data_cnt + 5'h1;
        else
          data_cnt <= data_cnt;
      else
        data_cnt <= 5'h0;
    end
  
  // Total data will be shift in STOP state
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        stop_cnt <= 2'b00;
      else if(current_state == STOP)
        if((count == osm_cnt) & bclk)
          stop_cnt <= stop_cnt + 2'b01;
        else
          stop_cnt <= stop_cnt;
      else
        stop_cnt <= 2'b00;
    end

  // Counter - OSM
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        count <= 4'b0000;
      else if(current_state != IDLE && bclk)
        if(count == osm_cnt)
          count <= 4'b0000;
        else
          count <= count + 4'b0001;
      else 
        if(bclk)
          count <= 4'b0000;
        else
          count <= count;
    end

  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        count_detect <= 0;
      else if(count == osm_cnt)
        count_detect <= 1;
      else
        count_detect <= 0;
    end

  // Current state register logic
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        current_state <= IDLE;
      else
        current_state <= next_state;
    end
  // Next state combination logic
  always @(current_state or start_detect or start_end or data_end or parity_end or stop_end)
    begin
      case(current_state)
        IDLE:  
          if(start_detect)
            next_state = START;
          else 
            next_state = IDLE;
        START: 
          if(start_end)
            next_state = RX_DATA;
          else
            next_state = START;
        RX_DATA: 
          if(data_end)
            if(pen)
              next_state = PARITY;
            else
              next_state = STOP;
          else
            next_state = RX_DATA;
        PARITY: 
          if(parity_end)
            next_state = STOP;
          else
            next_state = PARITY;
        STOP: 
          if(stop_end)
            next_state = IDLE;
          else
            next_state = STOP;
        default: next_state = IDLE;
      endcase
    end
`endprotect
endmodule
