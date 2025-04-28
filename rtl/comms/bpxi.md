# BPI Backend for AXI-4
This is a backend for the BPI based bridge. It supports AXI-4 bus transactions.

### Backend Commands
See the BPI documentation for reserved commands that are common to all backends. This commands listend here are specific to the BPXI backend.

### Address and Data fields
The constants 'A' and 'D' are used to represent the number of bytes of the address or data signals. These sizes are variable in the AXI-4 standard, typically 32 or 64 bits.

### Non Byte-Sized fields.
Fields whose size are not a multiple of 8 bits are right justified within their respective bytes. This is consistent with shifting in 8 bits at a time from the MSB. Since BPI fields of multiple bytes are always little-endian, only the final byte in an odd-sized fields can have less than 8 bits.

	Write Word					(Op, Address:A, Data:D) -> BResp
Write Data to Address using the full width of the bus. The BRESP signal is returned as a response.

	Read Word					(Op, Address:A) -> (Data:D, RResp)
Read Data from Address using the full width of the bus. The data is returned followed by the RRESP signal.