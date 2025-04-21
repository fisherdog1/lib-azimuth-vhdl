# Byte Procedure Interface (BPI) to AXI Manager
Adapts a simple 8-bit wide interface to an AXI manager. Suitable for controlling AXI over UART and other peripherals without a managing processor.

# Byte Procedure Interface
Commands start with one opcode byte followed by zero or more fields. Bus operations are executed by loading a write fifo with components. The 'T' determines the interpretation of data in the fifo for the specific type of operation. All multi-byte fields are little endian.

## Fields
L:				0-255 length
Data:			Data bytes having length of a preceding length field
T:				Bus operation type
F:				Status flags. Write 1 to clear the flag in each position, if it is indeed clearable.

## T Field
0x00:			Write data. First 4 bytes as 32 bit address. Determine access size by next byte, power of two encoded, e.g. 0x00 is a byte and 0x02 is a 32-bit word. The corresponding number of bytes follows.
0x01:			Read data. First 4 bytes as 32 bit address. Determine access size by next byte, power of two encoded, e.g. 0x00 is a byte and 0x02 is a 32-bit word.
0x80:			Indirect execute. The write buffer is interpreted as individual Execute Operation commands, without the opcode. The operation will not be reported as done until all individual operations have completed.

## Opcodes
0x00:			Reset interface
0x55: 			No operation

0x01: 			Get status
0x02 L Data:	Write data to write fifo
0x03 L:			Read data from read fifo
0x04 T:			Execute operation
0x05 T:			Test operation (check for support and correctness but do not execute)
0x10 F:			Clear status flags

## Status Field
The Get Status operation prompts a status response
Status bits
0: Write fifo overflow
1: Read fifo overflow
2: Operation not supported

2 byte write fifo level
2 byte read fifo level

## Frontend and Backend
BPI is structured in such a way that the front-end command state machine is separate from a back-end bus state machine. The latter is particular to the bus, in this case AXI, but could be another bus. The two sides communicate through the read/write fifos and through signals in the bpi_state_t type. The bus side has its own state, in the case of AXI it's bpix_state_t.

The frontend is responsible for parsing bytes which determine the command to be executed and any accompanying data. It does this by writing the write fifo or reading the read fifo. Writing is done by temporarily redirecting bytes coming in to the write fifo. Reads are done by opening up the read fifo to a peripheral (typically UART) transmitter.

The backend is engaged whenever the bpi_state asserts command_valid. The backend is responsible for calling bpi_end_command once it is done working to allow the parser to accept new commands. 

## Timing Relationships between Commands
The result of a command which fills the read fifo is visible atomically. The result bytes are either all available or no bytes are available. This prevents accidentally interpreting a command which is not complete. Similarly, the write fifo cannot be written while a command is ongoing, since commands typically need to pop from the write fifo. This prevents strange timing dependencies from developing due to misuse or interaction between commands.