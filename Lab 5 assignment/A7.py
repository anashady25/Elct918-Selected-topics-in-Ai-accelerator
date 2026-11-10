import time
import serial
import struct

# Configure the serial port
ser = serial.Serial('COM6', 115200, timeout=1)
FPGA_CLK_FREQ_HZ = 50_000_000  

def send_to_fpga(iact, weight, psum_in, csc_en, mux_sel, rst_n):
    packet = (rst_n << 78) | (mux_sel << 77) | (csc_en << 76) | (psum_in << 36) | (weight << 12) | iact
    byte_data = packet.to_bytes(10, byteorder='big')
    ser.write(byte_data)
    
    response = ser.read(5)
    if len(response) == 5:
        return int.from_bytes(response, byteorder='big')
    return None

# Helper to convert raw unsigned hex into a signed 8-bit integer (like Verilog does)
def to_signed_8bit(val):
    return val if val < 128 else val - 256

test_vector_array = [
    {"desc": "Software Reset (Clear accumulators)", "iact": 0x000, "weight": 0x000000, "csc": 0, "rst_n": 0},
    {"desc": "Dense / Non-zero test", "iact": 0x010, "weight": 0x040030, "csc": 1, "rst_n": 1},
    {"desc": "Zero Activation (Sparsity trigger)", "iact": 0x000, "weight": 0x040030, "csc": 1, "rst_n": 1},
    {"desc": "Zero Weight test", "iact": 0x020, "weight": 0x000000, "csc": 1, "rst_n": 1},
    {"desc": "Software Reset (Clear accumulators)", "iact": 0x000, "weight": 0x000000, "csc": 0, "rst_n": 0},
    {"desc": "CSC Disabled baseline", "iact": 0x010, "weight": 0x040030, "csc": 0, "rst_n": 1},
    {"desc": "CSC Testing random iact x weight", "iact": 0x110, "weight": 0x123456, "csc": 1, "rst_n": 1},
    {"desc": "CSC Testing at Alignment", "iact": 0x132, "weight": 0x654321, "csc": 1, "rst_n": 1},
    {"desc": "CSC Testing at NAlignment", "iact": 0x132, "weight": 0x654321, "csc": 0, "rst_n": 1},
    {"desc": "CSC Testing at Alignment", "iact": 0xACE, "weight": 0xEA2027, "csc": 1, "rst_n": 1},
    {"desc": "CSC at sparse", "iact": 0x132, "weight": 0x000000, "csc": 0, "rst_n": 1},
    {"desc": "CSC Testing at NAlignment", "iact": 0xACE, "weight": 0xEA2027, "csc": 0, "rst_n": 1},
    {"desc": "Zero activation", "iact": 0x000, "weight": 0x654321, "csc": 1, "rst_n": 1}
]

print("Starting PE Sparsity Array Test...\n")
script_start_time = time.perf_counter()

# Python variables to track the exact mathematical reference
expected_psum0 = 0
expected_psum1 = 0

for i, test in enumerate(test_vector_array):
    print(f"Test {i+1} ({test['desc']})")
    
    # 1. Exact Reference Calculation (Python Software Model)
    if test['rst_n'] == 0:
        expected_psum0 = 0
        expected_psum1 = 0
    elif test['csc'] == 1:
        # Extract the lower 8 bits (data value) based on your {count[3:0], value[7:0]} mapping
        iact_val = to_signed_8bit(test['iact'] & 0xFF)
        w0_val   = to_signed_8bit(test['weight'] & 0xFF)
        w1_val   = to_signed_8bit((test['weight'] >> 12) & 0xFF)
        
        expected_psum0 += (iact_val * w0_val)
        expected_psum1 += (iact_val * w1_val)
        
    # Mask to 20-bit to replicate hardware register boundaries
    exp_p0_hw = expected_psum0 & 0xFFFFF
    exp_p1_hw = expected_psum1 & 0xFFFFF
    expected_combined_hw = (exp_p1_hw << 20) | exp_p0_hw

    # 2. Hardware Execution
    result = send_to_fpga(test['iact'], test['weight'], psum_in=0, csc_en=test['csc'], mux_sel=0, rst_n=test['rst_n'])
    
    # 3. Error Measurement
    if result is not None:
        error = abs(expected_combined_hw - result)
        print(f"  -> Sending : iact={hex(test['iact'])}, weight={hex(test['weight'])}, csc_en={test['csc']}, rst_n={test['rst_n']}")
        print(f"  <- HW Psum : {hex(result)}")
        print(f"  <- SW Psum : {hex(expected_combined_hw)}")
        print(f"  ==> ERROR  : {error} {'(EXACT MATCH)' if error == 0 else '(MISMATCH)'}")
    else:
        print("  <- Timeout: No response from FPGA.")
    print("-" * 50)

ser.close()