module shift_rows(
    input   wire    [127:0]     data_in_t,
    input   wire    [127:0]     data_in_f,

    output  wire    [127:0]     shifted_data_t,
    output  wire    [127:0]     shifted_data_f
);
    //True value
    assign shifted_data_t[127:120] = data_in_t[127:120]; // [0+:8]
    assign shifted_data_t[95:88]   = data_in_t[95:88];   // [32+:8]
    assign shifted_data_t[63:56]   = data_in_t[63:56];   // [64+:8]
    assign shifted_data_t[31:24]   = data_in_t[31:24];   // [96+:8]
	
    assign shifted_data_t[119:112] = data_in_t[87:80];   // [8+:8]   <= [40+:8]
    assign shifted_data_t[87:80]   = data_in_t[55:48];   // [40+:8]  <= [72+:8]
    assign shifted_data_t[55:48]   = data_in_t[23:16];   // [72+:8]  <= [104+:8]
    assign shifted_data_t[23:16]   = data_in_t[119:112]; // [104+:8] <= [8+:8]
	
    assign shifted_data_t[111:104] = data_in_t[47:40];   // [16+:8]  <= [80+:8]
    assign shifted_data_t[79:72]   = data_in_t[15:8];    // [48+:8]  <= [112+:8]
    assign shifted_data_t[47:40]   = data_in_t[111:104]; // [80+:8]  <= [16+:8]
    assign shifted_data_t[15:8]    = data_in_t[79:72];   // [112+:8] <= [48+:8]
	
    assign shifted_data_t[103:96]  = data_in_t[7:0];     // [24+:8]  <= [120+:8]
    assign shifted_data_t[71:64]   = data_in_t[103:96];  // [56+:8]  <= [24+:8]
    assign shifted_data_t[39:32]   = data_in_t[71:64];   // [88+:8]  <= [56+:8]
    assign shifted_data_t[7:0]     = data_in_t[39:32];   // [120+:8] <= [88+:8]
    
    //False Value
    assign shifted_data_f[127:120] = data_in_f[127:120]; // [0+:8]
    assign shifted_data_f[95:88]   = data_in_f[95:88];   // [32+:8]
    assign shifted_data_f[63:56]   = data_in_f[63:56];   // [64+:8]
    assign shifted_data_f[31:24]   = data_in_f[31:24];   // [96+:8]
	
    assign shifted_data_f[119:112] = data_in_f[87:80];   // [8+:8]   <= [40+:8]
    assign shifted_data_f[87:80]   = data_in_f[55:48];   // [40+:8]  <= [72+:8]
    assign shifted_data_f[55:48]   = data_in_f[23:16];   // [72+:8]  <= [104+:8]
    assign shifted_data_f[23:16]   = data_in_f[119:112]; // [104+:8] <= [8+:8]
	
    assign shifted_data_f[111:104] = data_in_f[47:40];   // [16+:8]  <= [80+:8]
    assign shifted_data_f[79:72]   = data_in_f[15:8];    // [48+:8]  <= [112+:8]
    assign shifted_data_f[47:40]   = data_in_f[111:104]; // [80+:8]  <= [16+:8]
    assign shifted_data_f[15:8]    = data_in_f[79:72];   // [112+:8] <= [48+:8]
	
    assign shifted_data_f[103:96]  = data_in_f[7:0];     // [24+:8]  <= [120+:8]
    assign shifted_data_f[71:64]   = data_in_f[103:96];  // [56+:8]  <= [24+:8]
    assign shifted_data_f[39:32]   = data_in_f[71:64];   // [88+:8]  <= [56+:8]
    assign shifted_data_f[7:0]     = data_in_f[39:32];   // [120+:8] <= [88+:8]

endmodule