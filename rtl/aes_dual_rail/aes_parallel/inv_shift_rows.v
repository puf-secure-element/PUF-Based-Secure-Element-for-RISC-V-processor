module inv_shift_rows(
    input   wire    [127:0]     data_in_t,
    input   wire    [127:0]     data_in_f,

    output  wire    [127:0]     shifted_data_t,
    output  wire    [127:0]     shifted_data_f
);    
    // Row 0: No shift
    assign shifted_data_t[127:120] = data_in_t[127:120];
    assign shifted_data_t[95:88]   = data_in_t[95:88];  
    assign shifted_data_t[63:56]   = data_in_t[63:56];  
    assign shifted_data_t[31:24]   = data_in_t[31:24];  
    
    // Row 1: Shift Right by 1
    assign shifted_data_t[119:112] = data_in_t[23:16];  
    assign shifted_data_t[87:80]   = data_in_t[119:112];
    assign shifted_data_t[55:48]   = data_in_t[87:80];  
    assign shifted_data_t[23:16]   = data_in_t[55:48];  
    
    // Row 2: Shift Right by 2 (Identical to Left by 2)
    assign shifted_data_t[111:104] = data_in_t[47:40];  
    assign shifted_data_t[79:72]   = data_in_t[15:8];   
    assign shifted_data_t[47:40]   = data_in_t[111:104];
    assign shifted_data_t[15:8]    = data_in_t[79:72];  
    
    // Row 3: Shift Right by 3 (Equivalent to Left by 1)
    assign shifted_data_t[103:96]  = data_in_t[71:64];  
    assign shifted_data_t[71:64]   = data_in_t[39:32];  
    assign shifted_data_t[39:32]   = data_in_t[7:0];    
    assign shifted_data_t[7:0]     = data_in_t[103:96]; 

    // Row 0: No shift
    assign shifted_data_f[127:120] = data_in_f[127:120];
    assign shifted_data_f[95:88]   = data_in_f[95:88];  
    assign shifted_data_f[63:56]   = data_in_f[63:56];  
    assign shifted_data_f[31:24]   = data_in_f[31:24];  
    
    // Row 1: Shift Right by 1
    assign shifted_data_f[119:112] = data_in_f[23:16];  
    assign shifted_data_f[87:80]   = data_in_f[119:112];
    assign shifted_data_f[55:48]   = data_in_f[87:80];  
    assign shifted_data_f[23:16]   = data_in_f[55:48];  
    
    // Row 2: Shift Right by 2 (Identical to Left by 2)
    assign shifted_data_f[111:104] = data_in_f[47:40];  
    assign shifted_data_f[79:72]   = data_in_f[15:8];   
    assign shifted_data_f[47:40]   = data_in_f[111:104];
    assign shifted_data_f[15:8]    = data_in_f[79:72];  
    
    // Row 3: Shift Right by 3 (Equivalent to Left by 1)
    assign shifted_data_f[103:96]  = data_in_f[71:64];  
    assign shifted_data_f[71:64]   = data_in_f[39:32];  
    assign shifted_data_f[39:32]   = data_in_f[7:0];    
    assign shifted_data_f[7:0]     = data_in_f[103:96]; 

endmodule