module shift_rows(
    input   wire    [127:0]     data_in,
    
    output  wire    [127:0]     shifted_data
);

    assign shifted_data[127:120] = data_in[127:120]; // [0+:8]
    assign shifted_data[95:88]   = data_in[95:88];   // [32+:8]
    assign shifted_data[63:56]   = data_in[63:56];   // [64+:8]
    assign shifted_data[31:24]   = data_in[31:24];   // [96+:8]
	
    assign shifted_data[119:112] = data_in[87:80];   // [8+:8]   <= [40+:8]
    assign shifted_data[87:80]   = data_in[55:48];   // [40+:8]  <= [72+:8]
    assign shifted_data[55:48]   = data_in[23:16];   // [72+:8]  <= [104+:8]
    assign shifted_data[23:16]   = data_in[119:112]; // [104+:8] <= [8+:8]
	
    assign shifted_data[111:104] = data_in[47:40];   // [16+:8]  <= [80+:8]
    assign shifted_data[79:72]   = data_in[15:8];    // [48+:8]  <= [112+:8]
    assign shifted_data[47:40]   = data_in[111:104]; // [80+:8]  <= [16+:8]
    assign shifted_data[15:8]    = data_in[79:72];   // [112+:8] <= [48+:8]
	
    assign shifted_data[103:96]  = data_in[7:0];     // [24+:8]  <= [120+:8]
    assign shifted_data[71:64]   = data_in[103:96];  // [56+:8]  <= [24+:8]
    assign shifted_data[39:32]   = data_in[71:64];   // [88+:8]  <= [56+:8]
    assign shifted_data[7:0]     = data_in[39:32];   // [120+:8] <= [88+:8]

endmodule