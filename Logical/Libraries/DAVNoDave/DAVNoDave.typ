(********************************************************************
 * COPYRIGHT -- B&R Industrial Automation
 ********************************************************************
 * Library: DAVNoDave
 * File: DAVNoDave.typ
 * Author: morrisd
 * Created: May 26, 2009
 ********************************************************************
 * Functions and function blocks of library DAVNoDave
 ********************************************************************)
(**)
(*DAV Handle*)

TYPE
	DAVHandle_typ : 	STRUCT  (*Main DAVNoDave structure*)
		connection : DAVHandleConnect_typ; (*Connection data*)
		ident : UDINT; (*Identity for TCP / MPI comms*)
		pConfig : UDINT; (*Address of comms configuration*)
		pMapping : UDINT; (*Address of mapping configuration*)
		pBufferR : UDINT; (*Address of read buffer*)
		pBufferW : UDINT; (*Address of write buffer*)
		internal : USINT; (*Internal*)
		maxLinesConfig : UINT; (*Maximum number of lines in configuration*)
		maxLinesMapping : UINT; (*Maximum number of lines in mapping*)
		maxPrioirty : USINT; (*Maximum prioirty level found in the configuration data object*)
	END_STRUCT;
	DAVHandleConnect_typ : 	STRUCT  (*DAVNoDave communications*)
		protocol : USINT; (*Protocol (DAV_PROTOCOL_xxx)*)
		mpiSpeed : USINT; (*MPI speed (DAV_SPEED_xxx)*)
		mpiLocalAdr : USINT; (*MPI local address (usually 1)*)
		mpiPLCAdr : USINT; (*MPI PLC address (usually 2)*)
		tcpRack : USINT; (*TCP rack*)
		tcpSlot : USINT; (*TCP slot*)
		connectNum : USINT; (*MPI connection number*)
		connectNum2 : USINT; (*MPI connection number 2*)
		msgNum : USINT; (*Packet number*)
		pduNum : UINT; (*PDU number*)
		ackNum : USINT; (*Acknowledge number*)
	END_STRUCT;
END_TYPE

(**)
(*Data Object (per line)*)

TYPE
	DAVSendVar_typ : 	STRUCT  (*Structure per variable per variable*)
		area : USINT; (*Siemens - Area (DAV_AREA_xxx)*)
		db : UINT; (*Siemens - Data block number (only if area is DAV_AREA_DB)*)
		pdb : UDINT; (*Siemens - Pointer to Data block number (only if area is DAV_AREA_DB)*)
		actAdr : UINT; (*Siemens - Actual variable address (in BYTE's)*)
		bitAdr : UDINT; (*Siemens - Start address (in BIT's)*)
		pStartAdr : UDINT; (*Siemens - Pointer to Start address (must be a UINT)*)
		bitAdrB : USINT; (*Siemens - Start address bit position*)
		pStartAdrB : UDINT; (*Siemens - Pointer to start address bit position (must be a USINT)*)
		type : USINT; (*Siemens - Variable type (DAV_VAR_xxx)*)
		length : UINT; (*Siemens - Variable length*)
	END_STRUCT;
	DAVConfig_typ : 	STRUCT  (*Structure per line in the configuration data object*)
		var : DAVSendVar_typ; (*Variable details*)
		priority : USINT; (*Priority of variable*)
		pEnable : UDINT; (*Pointer to enable variable (must be a BOOL)*)
		brVarAdr : UDINT; (*B&R - Start address of variable(s)*)
		internal : USINT; (*Internal variable*)
	END_STRUCT;
	DAVMapping_typ : 	STRUCT  (*Structure per line in the mapping data object*)
		var : DAVSendVar_typ; (*Variable details*)
		priority : USINT; (*Priority of variable*)
		pEnable : UDINT; (*Pointer to enable variable (must be a BOOL)*)
		access : USINT; (*Access (0 = read, 1= write, 2 = both)*)
		brVarAdr : UDINT; (*B&R - Address of variable to store the value*)
		brVarLength : USINT; (*B&R - Length of variable*)
		brVarType : USINT; (*B&R - Variable type*)
		brPrevValue : UDINT; (*B&R - Previous value*)
		internal : USINT; (*Internal variable*)
		cfgIndex : UINT; (*Internal configuration index*)
	END_STRUCT;
END_TYPE
