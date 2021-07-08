(********************************************************************
 * COPYRIGHT -- B&R Industrial Automation
 ********************************************************************
 * Library: DAVNoDave
 * File: DAVNoDave.fun
 * Author: morrisd
 * Created: May 26, 2009
 ********************************************************************
 * Functions and function blocks of library DAVNoDave
 ********************************************************************)
(**)
(*Initialization*)

FUNCTION_BLOCK DAVinitialize (*Allocates memory for communications*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		reset : BOOL; (*Resets the function block in case of error or if you want to reload the dataobjects ...*)
		pDOConfig : UDINT; (*Address of the name of the data object used for configuration*)
		pDOMapping : UDINT; (*Address of the name of the data object used for variable mapping*)
		pMemIdent : UDINT; (*Pointer to memory allocated by user in InitUp*)
		numItemsConfig : UINT; (*Maximum number of items in the configuration data object*)
		numItemsMapping : UINT; (*Maximum number of items in the mapping data object*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
		handle : UDINT; (*Handle (for other functions)*)
	END_VAR
	VAR
		state : USINT;
		pConfig : REFERENCE TO DAVConfig_typ;
		pConfigSwap : REFERENCE TO DAVConfig_typ;
		pMapping : REFERENCE TO DAVMapping_typ;
		pMappingSwap : REFERENCE TO DAVMapping_typ;
		pDAV : REFERENCE TO DAVHandle_typ;
		pData : REFERENCE TO ARRAY[0..499] OF USINT;
		DatObjInfo_Config : DatObjInfo;
		DatObjInfo_Map : DatObjInfo;
		DatObjRead_0 : DatObjRead;
		charIdx : UDINT;
		configIdx : UINT;
		configTemp : DAVConfig_typ;
		orderIdx : UINT;
		scanCount : UDINT;
		curDataLength : UDINT;
		status_i : UINT;
		curVarType : UDINT;
		curDimensions : UDINT;
		mappingTemp : DAVMapping_typ;
		lengthToAllocate : UDINT;
		pDOData : UDINT;
		mappingIdx : UINT;
		straSplit : ARRAY[0..9] OF STRING[100];
		posNextNull : UINT;
		tmpAdr : UDINT;
		tmpVal : DINT;
		posPlus : UINT;
		memFreeFB : {REDUND_UNREPLICABLE} ARRAY[0..1] OF AsMemPartFree;
		memAllocFB : {REDUND_UNREPLICABLE} ARRAY[0..1] OF AsMemPartAllocClear;
		memHandle : {REDUND_UNREPLICABLE} ARRAY[0..1] OF UDINT;
		i : {REDUND_UNREPLICABLE} USINT;
	END_VAR
END_FUNCTION_BLOCK
(**)
(*Connection*)

FUNCTION_BLOCK DAVconnect (*Connects to a Siemens S7 or VIPA unit via ISO/TCP*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		pHandle : UDINT; (*Address of handle from DAVinitialize*)
		protocol : USINT; (*Connection mode. Use DAV_PROTOCOL_xxx*)
		pMPIinterface : UDINT; (*MPI interface to use (i.e. 'IF1')*)
		pMPIconnection : UDINT; (*MPI connection parameters. Use 0 for DAV_DEFAULT_MPI*)
		MPIspeed : USINT; (*MPI speed. Use DAV_SPEED_xxx*)
		MPIlocalAdr : USINT; (*MPI local address. Usually 1*)
		MPIplcAdr : USINT; (*MPI PLCl address. Usually 2*)
		pTCPsourceIP : UDINT; (*TCP ethernet interface - use 0 for listenning in on all interfaces.*)
		pTCPtargetIP : UDINT; (*TCP IP address to connect to*)
		TCPport : UINT; (*TCP port to use - use 0 for DAV_DEFAULT_PORT*)
		TCPrack : USINT; (*TCP rack number (usually 0)*)
		TCPslot : USINT; (*TCP slot number (usually 1)*)
		timeout : UINT; (*Timout time*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
		pduLength : UINT; (*Length of PDU (from PLC)*)
		portOpened : UINT; (*Port number used for connection*)
		TCPident : UDINT;
	END_VAR
	VAR
		pDAV : REFERENCE TO DAVHandle_typ;
		pBufferR : REFERENCE TO ARRAY[0..99] OF USINT;
		state : USINT;
		frmConfig : XOPENCONFIG;
		FRM_xopen_0 : FRM_xopen;
		TcpOpen_0 : TcpOpen;
		TcpClient_0 : TcpClient;
		DAVexchange_0 : DAVexchange;
		TON_10ms_ClientTimeout : TON_10ms;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK DAVdisconnect (*Disconnects current connection*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		pHandle : UDINT; (*Address of handle from DAVinitialize*)
		timeout : UINT;
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
	END_VAR
	VAR
		pDAV : REFERENCE TO DAVHandle_typ;
		TcpClose_0 : TcpClose;
		FRM_close_0 : FRM_close;
		DAVexchange_0 : DAVexchange;
		state : USINT;
	END_VAR
END_FUNCTION_BLOCK
(**)
(*Servicing*)

FUNCTION_BLOCK DAVclient (*Services communcations between a B&R and Siemens PLC*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		pHandle : UDINT; (*Address of handle from DAVinitialize*)
		pause : BOOL; (*Pause the data transfer*)
		timeout : UINT; (*Timeout when reading*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
		paused : BOOL; (*Whether the communications have been paused*)
		errorPackets : UINT; (*Number of misconfigured packets*)
		safeToDisconnect : BOOL; (*TRUE when the user can disconnect*)
	END_VAR
	VAR
		state : USINT;
		pDAV : REFERENCE TO DAVHandle_typ;
		pConfig : REFERENCE TO DAVConfig_typ;
		pMapping : REFERENCE TO DAVMapping_typ;
		ppBuffer : REFERENCE TO ARRAY[0..499] OF USINT;
		DAVexchange_0 : DAVexchange;
		currentMode : USINT;
		currentPriority : USINT;
		addIdx : UINT;
		findIdx : USINT;
		itemIdx : UINT;
		mapIdx : UINT;
		readIdx : UINT;
		numItems : USINT;
		varList : ARRAY[0..19] OF UINT;
		curValue : UDINT;
		dataLength : UINT;
		bufferFull : BOOL;
		moreLinesToScan : BOOL;
		writeValues : ARRAY[0..19] OF UDINT;
		responseSize : UINT;
		numItemsCfg : USINT;
		numItemsMap : USINT;
		maxSendSize : UINT;
		useVariable : BOOL;
		pEnable : REFERENCE TO BOOL;
	END_VAR
END_FUNCTION_BLOCK
(**)
(*Internal - Data exchange*)

FUNCTION_BLOCK DAVexchange (*Exchanges data between PLC's*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		pHandle : UDINT; (*Address of handle from DAVinitialize*)
		sendLength : UINT; (*Length of data to send*)
		timeout : UINT; (*Timeout when reading*)
		mpiFullExchange : BOOL; (*Full exchange of data, including Acknowledges. MPI protocol only*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
		recvLength : UINT; (*Received number of bytes (not including header)*)
		recvParamLength : UINT; (*Length of parameter area*)
		recvDataLength : UINT; (*Length of data area*)
		recvStartOfDataIdx : UINT; (*Number of bytes (index 0) before data starts*)
	END_VAR
	VAR
		state : USINT;
		pDAV : REFERENCE TO DAVHandle_typ;
		ppBuffer : REFERENCE TO ARRAY[0..19] OF USINT;
		TcpSend_0 : TcpSend;
		TcpRecv_0 : TcpRecv;
		TON_10ms_Timeout : TON_10ms;
		DAVmpiSend_0 : DAVmpiSend;
		DAVmpiRead_0 : DAVmpiRead;
		bufferRead : ARRAY[0..19] OF USINT;
		bufferSend : ARRAY[0..19] OF USINT;
		sendAckNumber : USINT;
		lastState : USINT;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK DAVmpiSend (*Sends data via serial (DVFrame library)*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		ident : UDINT; (*Ident from FRM_Xopen*)
		sendLength : UINT; (*Length to send*)
		pBufferW : UDINT; (*Pointer to data to send*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
	END_VAR
	VAR
		FRM_gbuf_0 : FRM_gbuf;
		FRM_write_0 : FRM_write;
		FRM_robuf_0 : FRM_robuf;
	END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK DAVmpiRead (*Reads data via serial (DVFrame library)*)
	VAR_INPUT
		enable : BOOL; (*Enable function block*)
		ident : UDINT; (*Ident from FRM_Xopen*)
		pBufferR : UDINT; (*Maximum length to read*)
		readLength : UINT; (*Pointer to storage to read data into*)
	END_VAR
	VAR_OUTPUT
		status : UINT; (*Function block status*)
		recvBufferLength : UINT;
	END_VAR
	VAR
		FRM_read_0 : FRM_read;
		FRM_rbuf_0 : FRM_rbuf;
	END_VAR
END_FUNCTION_BLOCK
(**)
(*Internal - Packets*)

FUNCTION DAVpacketHeader : UINT (*Initializes a packet with the required protocol and TPDU. Returns the index to the start of the TPDU*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketReadInit : UINT (*Initializes a packet for writing variables. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketReadAddVar : UINT (*Adds a variable to a read packet. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
		pVar : REFERENCE TO DAVSendVar_typ; (*Pointer to variable configuration to use*)
	END_VAR
	VAR
		ppBuffer : REFERENCE TO ARRAY[0..12] OF USINT;
		packetLength : UINT;
		paramLength : UINT;
	END_VAR
END_FUNCTION

FUNCTION DAVpacketWriteInit : UINT (*Initialiizes a packet for writing variables. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketWriteAddVar : UINT (*Adds a variable to a write packet. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
		pWriteBuffer : REFERENCE TO ARRAY[0..3] OF USINT; (*Pointer to write data*)
		pVar : REFERENCE TO DAVSendVar_typ; (*Pointer to variable configuration to use*)
	END_VAR
	VAR
		ppBuffer : REFERENCE TO ARRAY[0..12] OF USINT;
		packetLength : UINT;
		paramLength : UINT;
		dataLength : UINT;
		pBufferData : UDINT;
	END_VAR
END_FUNCTION

FUNCTION DAVpacketTCPconnect : UINT (*Creates packets for establishing a connection to a PLC via ISO/TCP. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..25] OF USINT; (*Pointer to buffer to build the message*)
		num : USINT; (*Packet to create*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketMPIconnect : UINT (*Creates packets for establishing a connection to a PLC via MPI. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..49] OF USINT; (*Pointer to buffer to build the message*)
		num : USINT; (*Packet to create*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketMPIdisconnect : UINT (*Creates packets for disconnect from a PLC via MPI. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..19] OF USINT; (*Pointer to buffer to build the message*)
		num : USINT; (*Packet to create*)
	END_VAR
END_FUNCTION

FUNCTION DAVpacketMPIack : UINT (*Creates packets for sending an Acknowledge to a PLC via MPI. Returns number of bytes in the buffer*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..11] OF USINT; (*Pointer to buffer to build the message*)
		ackNum : USINT; (*Acknowledge number to use*)
	END_VAR
END_FUNCTION

FUNCTION DAVresponseMPIconnect : UINT (*Compares the response of a packet from the PLC with what is expected. Returns if the packet is okay*)
	VAR_INPUT
		pDAV : REFERENCE TO DAVHandle_typ; (*Pointer to DAVHandle_typ*)
		pBuffer : REFERENCE TO ARRAY[0..49] OF USINT; (*Pointer to buffer to compare the message*)
		num : USINT; (*Packet to compare*)
	END_VAR
END_FUNCTION
(**)
(*Internal - Swap bytes*)

FUNCTION DAVswapWORD : UINT (*Swaps bytes in a WORD*)
	VAR_INPUT
		pUINT : REFERENCE TO UINT; (*Address of UINT variable*)
	END_VAR
END_FUNCTION

FUNCTION DAVswapDWORD : UDINT (*Swaps bytes and words in a DWORD*)
	VAR_INPUT
		pUDINT : REFERENCE TO UDINT; (*Address of UDINT variable*)
	END_VAR
END_FUNCTION
(**)
(*Internal - Get bytes*)

FUNCTION DAVgetHIBYTE : USINT (*Returns the hi-byte from a WORD*)
	VAR_INPUT
		input : UINT; (*Input WORD*)
	END_VAR
END_FUNCTION

FUNCTION DAVgetLOBYTE : USINT (*Returns the lo-byte from a WORD*)
	VAR_INPUT
		input : UINT; (*Input WORD*)
	END_VAR
END_FUNCTION

FUNCTION DAVaddressBITS : USINT (*Returns a byte of the start address*)
	VAR_INPUT
		startAdr : UDINT; (*Start address of variable*)
		byteNum : USINT; (*Byte number to return*)
	END_VAR
END_FUNCTION
(**)
(*Internal - Combine bytes*)

FUNCTION DAVmakeWORD : UINT (*Returns a WORD from 2 bytes*)
	VAR_INPUT
		hiByte : USINT; (*Hi-byte input*)
		loByte : USINT; (*Lo-byte input*)
	END_VAR
END_FUNCTION

FUNCTION DAVupdateVAR : USINT (*Updates the selected variable*)
	VAR_INPUT
		pMapping : REFERENCE TO DAVMapping_typ; (*Pointer to a DAVMapping_typ*)
		pBuffer : UDINT; (*Address of buffer to read the value*)
		transportBOOL : BOOL; (*Transport mechanism for BOOLEAN data*)
	END_VAR
	VAR
		pDynBool : REFERENCE TO BOOL;
		pDynByte : REFERENCE TO USINT;
		pDynWord : REFERENCE TO UINT;
		pDynDWord : REFERENCE TO UDINT;
		tempVar : UDINT;
	END_VAR
END_FUNCTION

FUNCTION DAVcalcVARadr : USINT
	VAR_INPUT
		pVar : REFERENCE TO DAVSendVar_typ; (*Pointer to DAVSendVar_typ*)
	END_VAR
	VAR
		pUserDB : REFERENCE TO UINT;
		pUserStartAdr : REFERENCE TO UINT;
		pUserStartAdrB : REFERENCE TO USINT;
	END_VAR
END_FUNCTION
(**)
(*Internal - Misc*)

FUNCTION DAVsplit : UINT
	VAR_INPUT
		pData : UDINT; (*Address of data to read*)
		pSplitData : REFERENCE TO ARRAY[0..9] OF STRING[100]; (*Pointer to array of strings*)
	END_VAR
	VAR
		ppData : REFERENCE TO ARRAY[0..499] OF USINT;
		ppSplitData : REFERENCE TO ARRAY[0..99] OF USINT;
		splitIdx : USINT;
		charIdx : UINT;
		copyIdx : UINT;
	END_VAR
END_FUNCTION

FUNCTION DAVisnumeric : BOOL
	VAR_INPUT
		pString : UDINT; (*Pointer to string to compare*)
	END_VAR
	VAR
		pData : REFERENCE TO ARRAY[0..99] OF USINT;
		charIdx : USINT;
	END_VAR
END_FUNCTION

FUNCTION DAVmpiCalcCS : BOOL
	VAR_INPUT
		pBuffer : REFERENCE TO ARRAY[0..99] OF USINT; (*Address of buffer*)
		len : UINT; (*Length to data*)
	END_VAR
	VAR
		charIdx : UINT;
		checksum : USINT;
	END_VAR
END_FUNCTION

FUNCTION DAVmpiSuffixCRC : UINT (*Performs DLE doubling, adds DLE and ETX and BCC (checksum)*)
	VAR_INPUT
		pBuffer : REFERENCE TO ARRAY[0..499] OF USINT; (*Pointer to buffer to build the message*)
		len : UINT; (*Length of data in the buffer*)
	END_VAR
	VAR
		bufferR : ARRAY[0..499] OF USINT;
		sourceIdx : UINT;
		destIdx : UINT;
		bcc : USINT;
	END_VAR
END_FUNCTION

FUNCTION DAVdecodeMPI : UINT (*Removes DLE doubling from a received message*)
	VAR_INPUT
		pBuffer : REFERENCE TO ARRAY[0..499] OF USINT; (*Pointer to buffer which contains the message*)
		bufferSize : UINT; (*Total size of the buffer*)
		dataLength : UINT; (*Length of data currently in the buffer*)
	END_VAR
	VAR
		bufferOrig : ARRAY[0..499] OF USINT;
		sourceIdx : UINT;
		destIdx : UINT;
	END_VAR
END_FUNCTION
