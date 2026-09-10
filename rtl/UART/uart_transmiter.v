module uart_transmitter ( // CLK&RST
                          input wire pclk,
                          input wire presetn,
                          input wire bclk,
                          
                          // FIFO
                          input wire[7:0] tx_data,
                          input wire      tx_empty_status,
                          output wire     tx_rd,

                          //UART setting
                          input wire        osm_sel,
                          input wire        eps,
                          input wire        pen,
                          input wire        stb,
                          input wire [1:0]  wls,
                          
                          // UART IF
                          output wire uart_txd
                        );
`protect                        
  parameter IDLE    = 3'b000; 
  parameter START   = 3'b001;
  parameter TX_DATA = 3'b010;
  parameter PARITY  = 3'b011;
  parameter STOP    = 3'b100;

  reg[2:0] current_state;
  reg[2:0] next_state;
  reg[7:0] data_out;
  reg[3:0] count;
  reg[3:0] data_cnt;
  reg[8:0] tx_shift_data;
  reg[1:0] stop_cnt;
  reg shift_en;
  reg count_detect;
  wire[3:0] osm_cnt;
  wire tx_data_complete;
  wire start_end;
  wire data_end;
  wire parity_end;
  wire stop_end;
  wire jump_state;
  wire stop_complete;
  reg  parity_bit;

  assign jump_state = count_detect & (count == 4'h0);
  assign tx_rd = ~tx_empty_status & (current_state == IDLE);
  assign start_end  = (current_state == START) & jump_state;
  assign data_end   = (current_state == TX_DATA) & (tx_data_complete) & jump_state;
  assign parity_end = (current_state == PARITY)  & jump_state;
  assign stop_end   = (current_state == STOP) & stop_complete & jump_state;
  assign tx_data_complete = (wls==2'b00) ? (data_cnt == 4'd5) :
                            (wls==2'b01) ? (data_cnt == 4'd6) :
                            (wls==2'b10) ? (data_cnt == 4'd7) :
                            (data_cnt == 4'd8);
  assign stop_complete = (stb==1'b0) ? (stop_cnt == 2'b01) : (stop_cnt == 2'b10);
  // Fixed bug Parity reverse, remain bug in data width, let student find out, revision 2.1
  // Update into always block assign parity_bit = eps ?((^data_out)): ~(^data_out); 
  assign osm_cnt = (osm_sel)? 4'hc : 4'hf;
  assign uart_txd = tx_shift_data[0];
  
  // Fixed bug Parity always calculate base on 8 bits data, revision 2.2
  always @(*) 
    begin
      if(eps) 
        case(wls)
          2'b00:  parity_bit = ^data_out[4:0];
          2'b01:  parity_bit = ^data_out[5:0];
          2'b10:  parity_bit = ^data_out[6:0];
          default:parity_bit = ^data_out[7:0];
        endcase
      else
        case(wls)
          2'b00:  parity_bit = ~(^data_out[4:0]);
          2'b01:  parity_bit = ~(^data_out[5:0]);
          2'b10:  parity_bit = ~(^data_out[6:0]);
          default:parity_bit = ~(^data_out[7:0]);
        endcase
    end

  // Enable shift bit
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        shift_en <= 0;
      else if(current_state != IDLE && count == 4'h0 && bclk == 1)
        shift_en <= 1;
      else 
        shift_en <= 0;
    end

  // Store bit to shift out in interface
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        tx_shift_data <= 9'h01;
      else if(shift_en)
        case(current_state)
          IDLE: tx_shift_data     <= 9'h1;
          START: tx_shift_data    <= {data_out,1'b0};
          TX_DATA: tx_shift_data  <= {1'b1,tx_shift_data[8:1]};
          PARITY: tx_shift_data   <= parity_bit;
          STOP : tx_shift_data    <= 2'b11;
        endcase
      else
        tx_shift_data <= tx_shift_data;
    end

  // Total data will be shift in DATA state
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        data_cnt <= 5'h0;
      else if(current_state == TX_DATA)
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
   
  // Get data from TX FIFO
  always @(posedge pclk or negedge presetn)
    begin
      if(~presetn)
        data_out <= 8'h00;
      else if(tx_rd)
        data_out <= tx_data;
      else
        data_out <= data_out;
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
  always @(current_state or tx_empty_status or start_end or data_end or parity_end or stop_end)
    begin
      case(current_state)
        IDLE:  
          if(~tx_empty_status)
            next_state = START;
          else 
            next_state = IDLE;
        START: 
          if(start_end)
            next_state = TX_DATA;
          else
            next_state = START;
        TX_DATA: 
          if(data_end)
            if(pen)
              next_state = PARITY;
            else
              next_state = STOP;
          else
            next_state = TX_DATA;
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


