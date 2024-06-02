import socket

# Define the IP address and port of the mGBA emulator's server
HOST = '127.0.0.1'
PORT = 2000

def send_chip_id(chip_id):
    # Prepare the bytes to send
    byte1 = 0x80
    byte2 = (chip_id >> 8) & 0xFF  # High 8 bits of the Chip ID
    byte3 = chip_id & 0xFF         # Low 8 bits of the Chip ID

    # Create a TCP/IP socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            # Connect to the emulator/server
            s.connect((HOST, PORT))
            # Send the bytes
            s.sendall(bytes([byte1, byte2, byte3]))
            print(f"Sent chip_id {chip_id:03X}: bytes [{byte1:02X}, {byte2:02X}, {byte3:02X}]")
        except Exception as e:
            print(f"Failed to send chip_id {chip_id:03X}: {e}")

# Example usage
send_chip_id(0x0137)  # Replace 0x0137 with the desired chip ID
