# convert_if_to_mem.py
import struct

with open('all_signal.bin', 'rb') as f:
    data = f.read()

with open('if_data.mem', 'w') as f:
    for i in range(len(data)):
        # Each byte: [7:4] = I (4 bits), [3:0] = Q (4 bits)
        byte_val = data[i]
        f.write(f"{byte_val:02X}\n")

print(f"Converted {len(data)} samples to if_data.mem")