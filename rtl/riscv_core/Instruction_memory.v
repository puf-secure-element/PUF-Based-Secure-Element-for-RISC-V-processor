module Instruction_memory(
input  wire [31:0] pc,
output wire [31:0] Instruction
);

reg [31:0] mem [0:1023];

initial begin

    // =========================================================
    // INITIAL CONFIGURATION WRITES
    // =========================================================

/*   // Write: address 0x100 – data 0x00000000
    mem[0] = 32'h10000293;     // addi x5,x0,0x100
    mem[1] = 32'h00000313;     // addi x6,x0,0
    mem[2] = 32'h0062A023;     // sw x6,0(x5)

    // Write: address 0x104 – data 0x00000036
    mem[3] = 32'h10400293;     // addi x5,x0,0x104
    mem[4] = 32'h03600313;     // addi x6,x0,0x36
    mem[5] = 32'h0062A023;     // sw x6,0(x5)

    // Write: address 0x108 – data 0x00000000
    mem[6] = 32'h10800293;     // addi x5,x0,0x108
    mem[7] = 32'h00000313;     // addi x6,x0,0
    mem[8] = 32'h0062A023;     // sw x6,0(x5)


    // =========================================================
    // Write: address 0x10C – data 0x00000023
    // CHÈN NOP TẠI ĐÂY
    // =========================================================

    mem[9]  = 32'h10C00293;    // addi x5,x0,0x10C
    mem[10] = 32'h02300313;    // addi x6,x0,0x23

    mem[11] = 32'h00000013;    // NOP
    mem[12] = 32'h00000013;    // NOP

    mem[13] = 32'h0062A023;    // sw x6,0(x5)
*/
    mem[0]  = 32'h000013B7;    // lui  x7,0x1          -> x7 = 0x1000
    mem[1]  = 32'h00000313;    // addi x6,x0,0         -> x6  = 0x00
    mem[2]  = 32'h01B00E13;    // addi x28,x0,0x1B     -> x28 = 0x1B
    mem[3]  = 32'h02300E93;    // addi x29,x0,0x23     -> x29 = 0x23

    mem[4]  = 32'h1063A023;    // sw   x6,0x100(x7)    MDR = 0x00
    mem[5]  = 32'h00000013;    // NOP
    mem[6]  = 32'h00000013;    // NOP

    mem[7]  = 32'h11C3A223;    // sw   x28,0x104(x7)   DLL = 0x1B
    mem[8]  = 32'h00000013;    // NOP
    mem[9]  = 32'h00000013;    // NOP

    mem[10] = 32'h1063A423;    // sw   x6,0x108(x7)    DLH = 0x00
    mem[11] = 32'h00000013;    // NOP
    mem[12] = 32'h00000013;    // NOP

    mem[13] = 32'h11D3A623;    // sw   x29,0x10C(x7)   LCR = 0x23

    // =========================================================
    // AES CONTROL = ENCRYPT
    // 0x08 = 0x02
    // =========================================================

    mem[14] = 32'h00800293;    // addi x5,x0,8
    mem[15] = 32'h00200313;    // addi x6,x0,2
    mem[16] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // ECC MODE = ENROLLMENT
    // 0x0C = 0x00
    // =========================================================

    mem[17] = 32'h00C00293;    // addi x5,x0,0x0C
    mem[18] = 32'h00000313;    // addi x6,x0,0
    mem[19] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // PUF CHALLENGE
    // Challenge = 0x12345678
    // =========================================================

    mem[20] = 32'h01400293;    // addi x5,x0,0x14

    mem[21] = 32'h12345337;    // lui  x6,0x12345
    mem[22] = 32'h67830313;    // addi x6,x6,0x678

    mem[23] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // PUF WINDOW
    // 0x18 = 50
    // =========================================================

    mem[24] = 32'h01800293;    // addi x5,x0,0x18
    mem[25] = 32'h03200313;    // addi x6,x0,50
    mem[26] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // PLAINTEXT
    //
    // 128-bit plaintext:
    // 11111111_22222222_33333333_44444444
    // =========================================================


    // ---------------------------------------------------------
    // PT[31:0] = 0x11111111
    // ---------------------------------------------------------

    mem[27] = 32'h02000293;    // addi x5,x0,0x20

    mem[28] = 32'h11111337;    // lui x6,0x11111
    mem[29] = 32'h11130313;    // addi x6,x6,0x111

    mem[30] = 32'h0062A023;    // sw x6,0(x5)


    // ---------------------------------------------------------
    // PT[63:32] = 0x22222222
    // ---------------------------------------------------------

    mem[31] = 32'h02400293;    // addi x5,x0,0x24

    mem[32] = 32'h22222337;    // lui x6,0x22222
    mem[33] = 32'h22230313;    // addi x6,x6,0x222

    mem[34] = 32'h0062A023;    // sw x6,0(x5)


    // ---------------------------------------------------------
    // PT[95:64] = 0x33333333
    // ---------------------------------------------------------

    mem[35] = 32'h02800293;    // addi x5,x0,0x28

    mem[36] = 32'h33333337;    // lui x6,0x33333
    mem[37] = 32'h33330313;    // addi x6,x6,0x333

    mem[38] = 32'h0062A023;    // sw x6,0(x5)


    // ---------------------------------------------------------
    // PT[127:96] = 0x44444444
    // ---------------------------------------------------------

    mem[39] = 32'h02C00293;    // addi x5,x0,0x2C

    mem[40] = 32'h44444337;    // lui x6,0x44444
    mem[41] = 32'h44430313;    // addi x6,x6,0x444

    mem[42] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // START
    // 0x00 = 1
    // =========================================================

    mem[43] = 32'h00000293;    // addi x5,x0,0
    mem[44] = 32'h00100313;    // addi x6,x0,1
    mem[45] = 32'h0062A023;    // sw x6,0(x5)


    // =========================================================
    // STATUS ADDRESS
    // x5 = 0x04
    // =========================================================

    mem[46] = 32'h00400293;    // addi x5,x0,0x04


    // =========================================================
    // POLL STATUS
    // =========================================================

    // lw x7,0(x5)
    mem[47] = 32'h0002A383;

    // andi x8,x7,4
    // ERROR bit
    mem[48] = 32'h0043F413;

    // if ERROR != 0 -> error_loop
    mem[49] = 32'h02041863;

    // andi x8,x7,2
    // DONE bit
    mem[50] = 32'h0023F413;

    // if DONE == 0 -> poll_status
    mem[51] = 32'hFE0408E3;


    // =========================================================
    // READ AES OUTPUT
    // =========================================================

    // AES_OUT_0 = 0x40
    mem[52] = 32'h04000293;
    mem[53] = 32'h0002A503;

    // AES_OUT_1 = 0x44
    mem[54] = 32'h04400293;
    mem[55] = 32'h0002A583;

    // AES_OUT_2 = 0x48
    mem[56] = 32'h04800293;
    mem[57] = 32'h0002A603;

    // AES_OUT_3 = 0x4C
    mem[58] = 32'h04C00293;
    mem[59] = 32'h0002A683;


    // =========================================================
    // SUCCESS LOOP -> jump forward to the Enroll-response sender at
    // mem[62] (skipping over mem[61]'s error-retry jal, which must stay
    // reachable at its original index for the WAIT_SHA poll loop above).
    // =========================================================

    mem[60] = 32'h0080006F;    // jal x0,8  -> mem[62]


    // =========================================================
    // ERROR LOOP -> RETRY
    // PUF is a physical, occasionally-noisy measurement; a single
    // PUF->ECC->SHA attempt is not guaranteed to succeed (timeout or
    // sha_error sends control_fsm to ERROR, which never sets key_ready).
    // Dead-ending here left key_ready stuck at 0 forever -- the whole
    // UART auto-encrypt path needs key_ready, so one bad measurement
    // permanently silenced the board until the next full reconfigure.
    // Jump back to re-issue START=1 and retry the whole chain instead.
    // =========================================================

    mem[61] = 32'hFB9FF06F;    // jal x0,-72  -> mem[43] (re-issue START=1)


    // =========================================================
    // ENROLL RESPONSE SENDER (runs once, right after key_ready)
    //
    // Reads the ECC helper data + SHA-derived key that were just computed
    // during the boot-time PUF->ECC->SHA sequence above (ECC_MODE was
    // configured as Enrollment at mem[17-19]), and sends them to the host
    // over UART as one 64-byte transmission (4 x 16-byte MANUAL_TX
    // blocks), framed for esp_new4.ino's Enroll parser:
    //
    //   Word0  (bytes 0-3):   STX(0x02) CMD(0x81) LEN(0x2C) RESERVED(0x00)
    //   Word1-3:              HELPER_OUT_0,1,2        (12 bytes)
    //   Word4-11:              KEY_OUT_0..7            (32 bytes)
    //   Word12 (bytes 48-51):  CRC ETX(0x03) RESERVED RESERVED
    //   Word13-15:             padding (never read by the host)
    //
    // The frame is deliberately byte-aligned to 32-bit register boundaries
    // (1 reserved byte after LEN, 2 after ETX) so this firmware only ever
    // needs straight register copies into MANUAL_TX_0..3 -- no bit-level
    // byte-shifting/realignment. CRC is read pre-computed from the
    // ENROLL_CRC hardware register (XOR-fold of the 44 payload bytes is
    // order-independent, so straight register copies here still line up
    // with whatever byte order the ESP receives and re-XORs).
    //
    // Generated + verified against a Python RV32I simulator exercising
    // this exact instruction sequence with synthetic register values
    // before being hand-placed here (see PR description).
    // =========================================================

    // -- Read HELPER_OUT_0..2 into x10,x11,x12 --
    mem[62]  = 32'h06000293;    // addi x5,x0,0x60        (HELPER_OUT_0)
    mem[63]  = 32'h0002A503;    // lw   x10,0(x5)
    mem[64]  = 32'h06400293;    // addi x5,x0,0x64        (HELPER_OUT_1)
    mem[65]  = 32'h0002A583;    // lw   x11,0(x5)
    mem[66]  = 32'h06800293;    // addi x5,x0,0x68        (HELPER_OUT_2)
    mem[67]  = 32'h0002A603;    // lw   x12,0(x5)

    // -- Read KEY_OUT_0..7 into x13..x20 --
    mem[68]  = 32'h09000293;    // addi x5,x0,0x90        (KEY_OUT_0)
    mem[69]  = 32'h0002A683;    // lw   x13,0(x5)
    mem[70]  = 32'h09400293;    // addi x5,x0,0x94        (KEY_OUT_1)
    mem[71]  = 32'h0002A703;    // lw   x14,0(x5)
    mem[72]  = 32'h09800293;    // addi x5,x0,0x98        (KEY_OUT_2)
    mem[73]  = 32'h0002A783;    // lw   x15,0(x5)
    mem[74]  = 32'h09C00293;    // addi x5,x0,0x9C        (KEY_OUT_3)
    mem[75]  = 32'h0002A803;    // lw   x16,0(x5)
    mem[76]  = 32'h0A000293;    // addi x5,x0,0xA0        (KEY_OUT_4)
    mem[77]  = 32'h0002A883;    // lw   x17,0(x5)
    mem[78]  = 32'h0A400293;    // addi x5,x0,0xA4        (KEY_OUT_5)
    mem[79]  = 32'h0002A903;    // lw   x18,0(x5)
    mem[80]  = 32'h0A800293;    // addi x5,x0,0xA8        (KEY_OUT_6)
    mem[81]  = 32'h0002A983;    // lw   x19,0(x5)
    mem[82]  = 32'h0AC00293;    // addi x5,x0,0xAC        (KEY_OUT_7)
    mem[83]  = 32'h0002AA03;    // lw   x20,0(x5)

    // -- Read ENROLL_CRC into x21 --
    mem[84]  = 32'h0B000293;    // addi x5,x0,0xB0        (ENROLL_CRC)
    mem[85]  = 32'h0002AA83;    // lw   x21,0(x5)

    // -- Build header_word = {STX,CMD,LEN,0x00} = 0x02812C00 into x22 --
    mem[86]  = 32'h02813B37;    // lui  x22,0x02813
    mem[87]  = 32'hC00B0B13;    // addi x22,x22,-1024     (0x02813000-0x400=0x02812C00)

    // -- Build tail_word = {CRC,ETX,0x00,0x00} into x23, from x21 --
    mem[88]  = 32'h018A9B93;    // slli x23,x21,24               (x23 = CRC<<24)
    mem[89]  = 32'h00030337;    // lui  x6,0x30                  (x6 = 0x00030000 = ETX<<16)
    mem[90]  = 32'h006BEBB3;    // or   x23,x23,x6               (x23 = tail_word)

    // -- Chunk 1: header, helper0, helper1, helper2 --
    mem[91]  = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[92]  = 32'h0162A023;    // sw   x22,0(x5)
    mem[93]  = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[94]  = 32'h00A2A023;    // sw   x10,0(x5)
    mem[95]  = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[96]  = 32'h00B2A023;    // sw   x11,0(x5)
    mem[97]  = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[98]  = 32'h00C2A023;    // sw   x12,0(x5)
    mem[99]  = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[100] = 32'h00100313;    // addi x6,x0,1
    mem[101] = 32'h0062A023;    // sw   x6,0(x5)                 (trigger send)
    mem[102] = 32'h08400293;    // addi x5,x0,0x84        (MANUAL_TX_STAT)
    mem[103] = 32'h0002AC03;    // poll1: lw x24,0(x5)
    mem[104] = 32'h001C7C13;    // andi x24,x24,1
    mem[105] = 32'hFE0C1CE3;    // bne  x24,x0,-8 -> mem[103]

    // -- Chunk 2: key0, key1, key2, key3 --
    mem[106] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[107] = 32'h00D2A023;    // sw   x13,0(x5)
    mem[108] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[109] = 32'h00E2A023;    // sw   x14,0(x5)
    mem[110] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[111] = 32'h00F2A023;    // sw   x15,0(x5)
    mem[112] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[113] = 32'h0102A023;    // sw   x16,0(x5)
    mem[114] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[115] = 32'h00100313;    // addi x6,x0,1
    mem[116] = 32'h0062A023;    // sw   x6,0(x5)                 (trigger send)
    mem[117] = 32'h08400293;    // addi x5,x0,0x84        (MANUAL_TX_STAT)
    mem[118] = 32'h0002AC03;    // poll2: lw x24,0(x5)
    mem[119] = 32'h001C7C13;    // andi x24,x24,1
    mem[120] = 32'hFE0C1CE3;    // bne  x24,x0,-8 -> mem[118]

    // -- Chunk 3: key4, key5, key6, key7 --
    mem[121] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[122] = 32'h0112A023;    // sw   x17,0(x5)
    mem[123] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[124] = 32'h0122A023;    // sw   x18,0(x5)
    mem[125] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[126] = 32'h0132A023;    // sw   x19,0(x5)
    mem[127] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[128] = 32'h0142A023;    // sw   x20,0(x5)
    mem[129] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[130] = 32'h00100313;    // addi x6,x0,1
    mem[131] = 32'h0062A023;    // sw   x6,0(x5)                 (trigger send)
    mem[132] = 32'h08400293;    // addi x5,x0,0x84        (MANUAL_TX_STAT)
    mem[133] = 32'h0002AC03;    // poll3: lw x24,0(x5)
    mem[134] = 32'h001C7C13;    // andi x24,x24,1
    mem[135] = 32'hFE0C1CE3;    // bne  x24,x0,-8 -> mem[133]

    // -- Chunk 4: tail (CRC,ETX,..), then 3 don't-care padding words --
    mem[136] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[137] = 32'h0172A023;    // sw   x23,0(x5)
    mem[138] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[139] = 32'h0002A023;    // sw   x0,0(x5)                 (padding)
    mem[140] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[141] = 32'h0002A023;    // sw   x0,0(x5)                 (padding)
    mem[142] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[143] = 32'h0002A023;    // sw   x0,0(x5)                 (padding)
    mem[144] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[145] = 32'h00100313;    // addi x6,x0,1
    mem[146] = 32'h0062A023;    // sw   x6,0(x5)                 (trigger send)
    mem[147] = 32'h08400293;    // addi x5,x0,0x84        (MANUAL_TX_STAT)
    mem[148] = 32'h0002AC03;    // poll4: lw x24,0(x5)
    mem[149] = 32'h001C7C13;    // andi x24,x24,1
    mem[150] = 32'hFE0C1CE3;    // bne  x24,x0,-8 -> mem[148]

    // -- Done: halt forever (hardware AES/UART auto-path continues to
    //    handle Auth traffic autonomously without any further CPU work,
    //    exactly as it already did before this Enroll code existed) --
    mem[151] = 32'h0000006F;    // jal x0,0

end

assign Instruction = mem[pc[31:2]];

endmodule
