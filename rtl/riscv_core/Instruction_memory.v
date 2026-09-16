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
    // *** TEMP DIAGNOSTIC -- REVERT BEFORE REAL USE ***
    //
    // mem[27..42] used to write a fixed 128-bit plaintext into AES_PT_*.
    // That was dead code: real plaintext arrives from the UART RX buffer
    // via hw_pt_load_valid, and only THAT path raises control_fsm's
    // plaintext_pending -- a CPU write to AES_PT_* never starts an AES op.
    // Reclaimed here for a firmware progress tracer, keeping mem[52] as the
    // entry point for everything below so no later branch offset moves.
    //
    // x30 holds the DEBUG_TRACE port (0xC0); every value stamped there
    // appears immediately on LEDR[7:0]. Read the LEDs as:
    //
    //   0x00  firmware never even reached mem[29] -- the CPU dies somewhere
    //         in the config writes at mem[0..28]
    //   0x01  all config writes done
    //   0x02  START=1 written, entering the status poll loop
    //   0x8x  live STATUS as the CPU reads it, bit7 added so that a status
    //         of 0 is still visibly distinct from 'never written':
    //           0x80 = STATUS reads 0     -> AXI *reads* return nothing,
    //                                        even though writes work
    //           0x81 = BUSY, still deriving the key (should be brief)
    //           0x83 = DONE -- loop is about to exit
    //           0x85 = ERROR bit set
    //   0x03  poll loop exited on DONE
    //   0x04  about to write MANUAL_TX_CTRL
    //   0x05  that write returned (LEDR9 must be lit by now)
    //   0x06  all four Enroll chunks pushed, firmware finished
    //   0x0F  control_fsm reported ERROR; retrying START
    //
    // A resting value therefore names the exact instruction range that hangs.
    // =========================================================

    mem[27] = 32'h0C000F13;    // addi x30,x0,0xC0       ; x30 = DEBUG_TRACE
    mem[28] = 32'h00100F93;    // addi x31,x0,1
    mem[29] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=01 cau hinh xong

    // ---- START = 1 (re-entered from the error path at mem[51]) ----
    mem[30] = 32'h00000293;    // addi x5,x0,0x00        ; SHA_ADDR_CTRL
    mem[31] = 32'h00100313;    // addi x6,x0,1
    mem[32] = 32'h0062A023;    // sw   x6,0(x5)          ; START=1
    mem[33] = 32'h00200F93;    // addi x31,x0,2
    mem[34] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=02 da ghi START
    mem[35] = 32'h00400293;    // addi x5,x0,0x04        ; STATUS

    // ---- poll STATUS until DONE, stamping the live value each pass ----
    mem[36] = 32'h0002A383;    // lw   x7,0(x5)          ; doc STATUS
    mem[37] = 32'h0803E493;    // ori  x9,x7,0x80        ; danh dau bit7
    mem[38] = 32'h009F2023;    // sw   x9,0(x30)         ; TRACE=0x80|STATUS (live)
    mem[39] = 32'h0043F413;    // andi x8,x7,4           ; bit ERROR
    mem[40] = 32'h02041263;    // bne  x8,x0,+36        -> mem[49]
    mem[41] = 32'h0023F413;    // andi x8,x7,2           ; bit DONE
    mem[42] = 32'hFE0404E3;    // beq  x8,x0,-24       -> mem[36] (lap tiep)

    // ---- success ----
    mem[43] = 32'h00300F93;    // addi x31,x0,3
    mem[44] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=03 thoat poll, DONE=1
    mem[45] = 32'h01C0006F;    // jal  x0,+28          -> mem[52]
    mem[46] = 32'h00000013;    // nop
    mem[47] = 32'h00000013;    // nop
    mem[48] = 32'h00000013;    // nop

    // ---- ERROR: PUF is a noisy physical measurement, so a single
    //      PUF->ECC->SHA attempt can legitimately fail. Stamp it and
    //      re-issue START rather than dead-ending with key_ready stuck
    //      at 0, which would silence the board until the next reconfigure.
    mem[49] = 32'h00F00F93;    // addi x31,x0,0x0F
    mem[50] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=0F FSM bao ERROR
    mem[51] = 32'hFADFF06F;    // jal  x0,-84         -> mem[30] (thu lai START)

    // ---- post-loop: hand over to the Enroll sender ----
    //      The bare manual-TX probe that used to sit here has been removed:
    //      it fired a 16-byte block of whatever aes_ct_reg happened to hold
    //      (all zeros), which prepended 16 junk bytes to the Enroll frame AND
    //      left the transmitter busy, so the first real chunk's trigger was
    //      swallowed. LEDR9 now lights on the first genuine Enroll block,
    //      which is what it was meant to indicate all along. --
    mem[52] = 32'h00400F93;    // addi x31,x0,4
    mem[53] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=04 vao trinh gui Enroll
    mem[54] = 32'h00000013;    // nop
    mem[55] = 32'h00000013;    // nop
    mem[56] = 32'h00000013;    // nop
    mem[57] = 32'h00000013;    // nop
    mem[58] = 32'h00000013;    // nop
    mem[59] = 32'h00000013;    // nop
    mem[60] = 32'h0080006F;    // jal  x0,+8             -> mem[62] (trinh gui Enroll)
    mem[61] = 32'h00000013;    // nop


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

    // -- Four 16-byte blocks. Each one WAITS FOR AN IDLE TRANSMITTER FIRST,
    //    then stages MANUAL_TX_3..0 and triggers.
    //
    //    The previous order (stage -> trigger -> wait) never protected its
    //    own trigger, only the next one, and uart_tx_buffer samples
    //    encrypted_plaintext_valid solely in its !tx_active branch -- so a
    //    trigger arriving while the previous block was still going was
    //    swallowed without a trace. Measured in RTL simulation: 3 of 5
    //    triggers silently dropped, plus one byte lost to a full FIFO,
    //    24 of 80 bytes reaching the pin. Same 15 instructions per block,
    //    so no index below shifts. --

    // -- Chunk 1: header + helper0..2 --
    mem[91] = 32'h08400293;    // addi x5,x0,0x84        (Khoi 1 header+helper: MANUAL_TX_STAT)
    mem[92] = 32'h0002AC03;    // lw   x24,0(x5)         ; cho TX ranh HAN
    mem[93] = 32'h001C7C13;    // andi x24,x24,1
    mem[94] = 32'hFE0C1CE3;    // bne  x24,x0,-8        -> mem[92]
    mem[95] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[96] = 32'h0162A023;    // sw   x22,0(x5)
    mem[97] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[98] = 32'h00A2A023;    // sw   x10,0(x5)
    mem[99] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[100] = 32'h00B2A023;    // sw   x11,0(x5)
    mem[101] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[102] = 32'h00C2A023;    // sw   x12,0(x5)
    mem[103] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[104] = 32'h00100313;    // addi x6,x0,1
    mem[105] = 32'h0062A023;    // sw   x6,0(x5)          ; KICH gui 16 byte

    // -- Chunk 2: key0..3 --
    mem[106] = 32'h08400293;    // addi x5,x0,0x84        (Khoi 2 key0-3: MANUAL_TX_STAT)
    mem[107] = 32'h0002AC03;    // lw   x24,0(x5)         ; cho TX ranh HAN
    mem[108] = 32'h001C7C13;    // andi x24,x24,1
    mem[109] = 32'hFE0C1CE3;    // bne  x24,x0,-8        -> mem[107]
    mem[110] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[111] = 32'h00D2A023;    // sw   x13,0(x5)
    mem[112] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[113] = 32'h00E2A023;    // sw   x14,0(x5)
    mem[114] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[115] = 32'h00F2A023;    // sw   x15,0(x5)
    mem[116] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[117] = 32'h0102A023;    // sw   x16,0(x5)
    mem[118] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[119] = 32'h00100313;    // addi x6,x0,1
    mem[120] = 32'h0062A023;    // sw   x6,0(x5)          ; KICH gui 16 byte

    // -- Chunk 3: key4..7 --
    mem[121] = 32'h08400293;    // addi x5,x0,0x84        (Khoi 3 key4-7: MANUAL_TX_STAT)
    mem[122] = 32'h0002AC03;    // lw   x24,0(x5)         ; cho TX ranh HAN
    mem[123] = 32'h001C7C13;    // andi x24,x24,1
    mem[124] = 32'hFE0C1CE3;    // bne  x24,x0,-8        -> mem[122]
    mem[125] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[126] = 32'h0112A023;    // sw   x17,0(x5)
    mem[127] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[128] = 32'h0122A023;    // sw   x18,0(x5)
    mem[129] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[130] = 32'h0132A023;    // sw   x19,0(x5)
    mem[131] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[132] = 32'h0142A023;    // sw   x20,0(x5)
    mem[133] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[134] = 32'h00100313;    // addi x6,x0,1
    mem[135] = 32'h0062A023;    // sw   x6,0(x5)          ; KICH gui 16 byte

    // -- Chunk 4: tail + padding --
    mem[136] = 32'h08400293;    // addi x5,x0,0x84        (Khoi 4 tail+dem: MANUAL_TX_STAT)
    mem[137] = 32'h0002AC03;    // lw   x24,0(x5)         ; cho TX ranh HAN
    mem[138] = 32'h001C7C13;    // andi x24,x24,1
    mem[139] = 32'hFE0C1CE3;    // bne  x24,x0,-8        -> mem[137]
    mem[140] = 32'h07C00293;    // addi x5,x0,0x7C        (MANUAL_TX_3)
    mem[141] = 32'h0172A023;    // sw   x23,0(x5)
    mem[142] = 32'h07800293;    // addi x5,x0,0x78        (MANUAL_TX_2)
    mem[143] = 32'h0002A023;    // sw   x0,0(x5)
    mem[144] = 32'h07400293;    // addi x5,x0,0x74        (MANUAL_TX_1)
    mem[145] = 32'h0002A023;    // sw   x0,0(x5)
    mem[146] = 32'h07000293;    // addi x5,x0,0x70        (MANUAL_TX_0)
    mem[147] = 32'h0002A023;    // sw   x0,0(x5)
    mem[148] = 32'h08000293;    // addi x5,x0,0x80        (MANUAL_TX_CTRL)
    mem[149] = 32'h00100313;    // addi x6,x0,1
    mem[150] = 32'h0062A023;    // sw   x6,0(x5)          ; KICH gui 16 byte

    // -- Done: halt forever (hardware AES/UART auto-path continues to
    //    handle Auth traffic autonomously without any further CPU work,
    //    exactly as it already did before this Enroll code existed) --
    // -- Wait for all 64 bytes to actually leave the wire, then stamp 06.
    //    MANUAL_TX_STAT now covers the TX FIFO too, so this really does
    //    mean 'frame fully transmitted', not just 'handed to the FIFO'. --
    mem[151] = 32'h08400293;    // addi x5,x0,0x84        (MANUAL_TX_STAT)
    mem[152] = 32'h0002AC03;    // lw   x24,0(x5)         ; cho 64 byte ra het day
    mem[153] = 32'h001C7C13;    // andi x24,x24,1
    mem[154] = 32'hFE0C1CE3;    // bne  x24,x0,-8         -> mem[152]
    mem[155] = 32'h00600F93;    // addi x31,x0,6
    mem[156] = 32'h01FF2023;    // sw   x31,0(x30)        ; TRACE=06 Enroll gui xong
    mem[157] = 32'h0000006F;    // jal  x0,0              ; dung han

end

assign Instruction = mem[pc[31:2]];

endmodule
