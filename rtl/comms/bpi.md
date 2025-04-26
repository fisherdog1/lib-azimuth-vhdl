# Byte Procedure Interface Frontend
The BPI frontend defines a set of byte-oriented commands which are used to control BPI-based bridges. Commands are divided into categories based on whether they concern the fronted or an available backend. The backend is bus protocol specific, and defines its own commands atop the standard backend command set. Bus protocol specific commands are not described here.

## Resets
Different components of the BPI bridge have independent resets. A reset of each component has different meaning. The frontend is able to report what type of reset it was last subject to.

### Command/Response Space Reset
Each backend's command and response spaces can be reset. Doing so marks them as empty. There is a separate reset on each side of every command/response space. The frontend is in charge of asserting this reset.

### Frontend Reset
A frontend reset restores the frontend to its original configuration and resets the frontend status field. It is recommended to effect a frontend reset before issuing a set of commands. Such a reset does not affect any backends.

### Backend Reset
A backend reset resets the currently selected backend. Performing this reset while a backend has ongoing transactions may leave the system in an invalid state. It should only be used for extreme post mortem debugging, or triggered automatically by a system reset. If a backend is not clocked, its reset must not be deasserted.

### Bridge Reset
A bridge reset resets the frontend and all backends. This reset should be used when first connecting to a device under test, when it is known that none of the backends have ongoing transactions. When the bridge reset is deasserted, the frontend, backend, and command/response space resets are deasserted at the same time.

### System Reset
A system reset will attempt to trigger the highest level reset the bridge has access to. The mechanism for taking control of system reset infrastructure is not described here. When triggered, the system reset will be deasserted, then the bridge reset.

## Commands
### Command Properties
Commands can have the following properties, which may aid in choosing between similar commands or for debugging.

(K) Constant size
The command/response always takes/produces the same number of bytes at the frontend

(B) Blocking
The command will prevent the frontend from being used until it completes, usually because it has both a command and response phase.

(C) Completes

All Frontend commands only require the frontend to be operational to complete. However, frontend commands which execute the backend and wait for a response may hang.

## Command Fields
Commands are represented by function / return syntax such as the following:
Opcode, Data:2 -> Response
Opcode, Length:2, Data:Length -> Response:Length\*2

Each comma-separated item is a field in the command or its response respectively. Each item may be followed by a colon and size in bytes, otherwise the size is one byte. An expression may follow the colon, and may operate on the unsigned value of any previous fields. All fields that are multiple bytes long are little-endian.

Frontend commands are executed by sending the fields specified over the peripheral command channel. Backend commands are executed by reading from their command space. Frontend responses are immediately sent over the peripheral response channel. backend responses are written to their response space.


### Named fields
The following fields have a specific meaning. Any other field names are chosen only for descriptiveness.

	Opcode
Constant byte that is defined per command in the command encoding reference section.

	Success
Zero represents success, some nonzero values are defined here, and any other value is a specific error particular to that command.

	2:	Unspecified failure
	3:	Not supported

	Version
Two binary-coded-decimal digits representing the major (msbs) and minor (lsbs) version of the queried device. The frontend version described here is 0.0

	FrontendStatus:2
Status of the frontend and selected backend.

	0:	BackendUnavailable
When one, the selected backend has no clock or is stuck in reset, and cannot accept commands.

	1: CommandFull
When one, the command space is full. No more data can be written to the selected command space.

	2: CommandOverflow
When one, the command space of the selected backend was written while full, and data has been lost. This bit is reset by clearing the command space.

	3: ResponseFull
When one, the response space is full. A backend command may be blocking as a result. The user should read data from the response space to make more room.

	4: ResponseOverflow
When one, the response space of the selected backend was written while full, and data has been lost. This can happen for backend commands that are unable to block while the response space is full. This bit is reset by clearing the response space.

	5: ResponseUnderflow
More response bytes were requested than available. This bit is reset by any Response command that does not underflow.

## Bus Hangs
Most backend operations which create bus transactions cannot be cancelled, unless the specific bus protocol supports some form of cancellation. For commands that are blocking, this can freeze the entire bridge. For this reason, it is recommended to use separate WriteCommand, Execute, and ReadResponse commands. This ensures that only intended commands are run and the frontend will not be frozen.

If a backend is reset while it is executing a command, it will almost always leave the bus in an invalid state, and so a reset cannot be used to work around bus hangs. The purpose of a backend reset is solely to regain control of the backend to perform post-mortem debugging.

The backend can be hung if it runs out of response space. If this is a possibility, the user should continuously query the response space status. If the response space is marked as full, then the backend is waiting for space. Response data should be read to allow the backend to continue.

## Length Overflows
Any time a Length field is given as its max value, E.g. 255 for a single byte, it means the actual length is that max value or more. When a response is longer than the maximum length value, multiple ReadResponse commands need to be used to obtain the full response.


### Commands for both Frontend and Backend
	NoOp						(Op)
Does nothing.

	GetStatus					(Op) -> FrontendStatus:2 or BackendStatus
Get the frontend/backend status. The frontend status field is standardized, while each backend defines its own BackendStatus field.

	GetVersion					(Op) -> Version
Check the version of the frontend/backend.

	GetCommandSupported			(Op, SupportedOpcode) -> Success
Check if a command is supported by providing its opcode.


### Frontend Commands
	BackendSelect				(Op, BackendIndex) -> Success
Select which backend (bus) to use. Backend 0 is selected after reset. Changing backends does not affect the ongoing operation of that backend.

	CommandWrite				(Op, Length, Data:Length) -> Success
Write data to the backend command space.

	CommandVerify				(Op, Checksum) -> Success
Verify integrity of all previous writes to command space. When this command is not successful, the command space is cleared.

	CommandExecute				(Op)
Execute one backend command from the command space. The executed command is always a backend command, so its response is written to the response space.

	CommandLength				(Op) -> Length:4
Read the length of the command space.

	ResponseRead				(Op, Length) -> Response:Length
Read data from the backend response space.

	ResponseLength				(Op) -> Length:4
Read the length of the first available response. Incomplete responses will not appear here. However, see the section on Length Overflows.

	MatchResponseRead			(Op, Match, Length) -> Response:Length
Read response space data for the first response matching the Match field. The Match and Length fields must be the same values from a preceding MatchResponse command.

	MatchResponseLength			(Op, Match) -> (Success, Length)
Check for a response corresponding to the Match field. If such a response is available, the command is successful, and the response can be read via the ReadMatchResponse command. Length is always zero for an unsuccessful MatchResponse command. This command is needed to support commands which deal with out-of-order bus transactions, which may generate response data in an arbitrary order. Responses which are visible to the oridinary ReadResponse command are never visible to the Match commands.


### Backend Commands
	Except						(Op)
Clears the command space if the previous backend command was unsuccessful. Used to abort a sequence of commands.

	Readback					(Op, Length) -> Readback:Length
Bytes from the command space are copied directly to the response space. Can be useful for debugging.
