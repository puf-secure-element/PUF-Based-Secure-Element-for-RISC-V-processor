module uart_interrupt( output wire tx_fifo_full,
                       output wire tx_fifo_empty,
                       output wire rx_fifo_full,
                       output wire rx_fifo_empty,
                       output wire parrity_error,

                       // Enable
                       input wire en_tx_fifo_full,
                       input wire en_tx_fifo_empty,
                       input wire en_rx_fifo_full,
                       input wire en_rx_fifo_empty,
                       input wire en_parrity_error,

                       // Status
                       input wire tx_full_status,
                       input wire tx_empty_status,
                       input wire rx_full_status,
                       input wire rx_empty_status,
                       input wire parrity_error_status
                     );
  
  assign tx_fifo_full   = tx_full_status        & en_tx_fifo_full;
  assign tx_fifo_empty  = tx_empty_status       & en_tx_fifo_empty;
  assign rx_fifo_full   = rx_full_status        & en_rx_fifo_full;
  assign rx_fifo_empty  = rx_empty_status       & en_rx_fifo_empty;
  assign parrity_error  = parrity_error_status  & en_parrity_error;

endmodule
