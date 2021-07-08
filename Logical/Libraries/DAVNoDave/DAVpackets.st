(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVpackets.st																																																	*)
(* Author: 				morrisd																																																				*)
(* Created: 			May 28, 2009																																																	*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketHeader																																																							*)
(*==============================================================================================================================*)
(* Initializes a packet header dependant upon the protocol																																			*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketHeader

	(* ISO/TCP Protocol *)		
	IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
		pBuffer[00]:= 16#03;																	(* Version *)
		pBuffer[01]:= 16#00;																	(* Reserved *)
		pBuffer[02]:= 16#00;																	(* Packet length hi-byte *)
		pBuffer[03]:= 16#13;																	(* Packet length lo-byte *)
		pBuffer[04]:= 16#02;																	(* Fixed *)
		pBuffer[05]:= 16#F0;																	(* Fixed *)
		pBuffer[06]:= 16#80;																	(* Fixed *)

		(* Return the length of data in the buffer *)
		DAVpacketHeader:= 7;

	(* MPI Protocol *)
	ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
		pBuffer[00]:= 16#04;																	(* Fixed *)
		pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;		(* MPI address *)
		pBuffer[02]:= 16#80;																	(* Fixed *)
		pBuffer[03]:= 16#0C;																	(* Fixed *)
		pBuffer[04]:= pDAV.connection.connectNum2; 						(* Conenction number 2 (target?) *)
		pBuffer[05]:= pDAV.connection.connectNum;							(* Connection number 1 (local?) *)
		pBuffer[06]:= 16#F1;																	(* Fixed *)
		pBuffer[07]:= pDAV.connection.msgNum;									(* Message number *)
			
		(* Increase message number *)
		pDAV.connection.ackNum:= pDAV.connection.msgNum;
		pDAV.connection.msgNum:= (pDAV.connection.msgNum MOD 255) + 1;	(* Any value between 1 and 255 *)

		(* Return the length of data in the buffer *)
		DAVpacketHeader:= 8;
	
	(* Invalid protocol *)
	ELSE
		
		(* Return the length of data in the buffer *)
		DAVpacketHeader:= 0;
	END_IF


	(* Valid protocol *)
	IF(DAVpacketHeader > 0)THEN

		(* Increase PDU number *)
		pDAV.connection.pduNum:= pDAV.connection.pduNum + 1;
	
		(* Header TPDU *)
		pBuffer[DAVpacketHeader + 00]:= 16#32;																	(* Fixed *)
		pBuffer[DAVpacketHeader + 01]:= 16#01;																	(* Message type (1) *)
		pBuffer[DAVpacketHeader + 02]:= 16#00;																	(* Unknown hi-byte *)
		pBuffer[DAVpacketHeader + 03]:= 16#00;																	(* Unknown lo-bute *)
		pBuffer[DAVpacketHeader + 04]:= DAVgetHIBYTE(pDAV.connection.pduNum);		(* Sequence number hi-byte *)
		pBuffer[DAVpacketHeader + 05]:= DAVgetLOBYTE(pDAV.connection.pduNum);		(* Sequence number lo-byte *)
		pBuffer[DAVpacketHeader + 06]:= 16#00;																	(* Parameter length hi-byte *)
		pBuffer[DAVpacketHeader + 07]:= 16#00;																	(* Parameter length lo-byte *)
		pBuffer[DAVpacketHeader + 08]:= 16#00;																	(* Data length hi-byte *)
		pBuffer[DAVpacketHeader + 09]:= 16#00;																	(* Data length lo-byte *)
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketReadInit																																																			*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketReadInit																																																						*)
(*==============================================================================================================================*)
(* Initializes a packet to READ multiple variables																																							*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketReadInit

	(* Create the packetHeader *)
	DAVpacketReadInit:= DAVpacketHeader(ADR(pDAV), ADR(pBuffer));

	(* Valid header *)
	IF(DAVpacketReadInit > 0)THEN
	
		(* Header TPDU *)
		pBuffer[DAVpacketReadInit + 06]:= 16#00;							(* Parameter length hi-byte *)
		pBuffer[DAVpacketReadInit + 07]:= 16#02;							(* Parameter length lo-byte *)
		pBuffer[DAVpacketReadInit + 08]:= 16#00;							(* Data length hi-byte *)
		pBuffer[DAVpacketReadInit + 09]:= 16#00;							(* Data length lo-byte *)

		(* Parameter Area *)
		pBuffer[DAVpacketReadInit + 10]:= 16#04;							(* Function (READ) *)
		pBuffer[DAVpacketReadInit + 11]:= 16#00;							(* Number of items (0) *)
		
		(* Return the number of bytes in the buffer *)
		DAVpacketReadInit:= DAVpacketReadInit + 12;						(* ISO/TCP= 19, MPI= 20 *)
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketReadInit																																																			*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketReadAddVar																																																					*)
(*==============================================================================================================================*)
(* Adds a variable to a READ packet																																															*)
(* Note:																																																												*)
(*			1) The packet length in the ISO/TCP header needs changing.																															*)
(*			2) The parameter length needs changing.																																									*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketReadAddVar
	
	(* ISO/TCP Protocol *)		
	IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
	
		(* Update the packetLength as part of the ISO/TCP Protocol *)
		packetLength:= DAVmakeWORD(pBuffer[02], pBuffer[03]) + 12;
		pBuffer[02]:= DAVgetHIBYTE(packetLength);							(* Packet length hi-byte *)
		pBuffer[03]:= DAVgetLOBYTE(packetLength);							(* Packet length lo-byte *)

		(* Set offset *)
		DAVpacketReadAddVar:= 7;

	(* MPI Protocol *)
	ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN

		(* Set offset *)
		DAVpacketReadAddVar:= 8;

	(* Invalid protocol *)
	ELSE
		DAVpacketReadAddVar:= 0;
	END_IF


	(* Valid protocol *)
	IF(DAVpacketReadAddVar > 0)THEN
 		
		(* Update variable address *)
		DAVcalcVARadr(ADR(pVar));

		(* Header TPDU - get the parameter and data lengths *)
		paramLength:= DAVmakeWORD(pBuffer[DAVpacketReadAddVar + 6], pBuffer[DAVpacketReadAddVar + 7]);
		
		(* Access memory *)
		ppBuffer ACCESS ADR(pBuffer) + DAVpacketReadAddVar + 10 + paramLength;
		
		(* Parameter Area *)
		ppBuffer[00]:= 16#12;																	(* Fixed *)
		ppBuffer[01]:= 16#0A;																	(* Fixed *)
		ppBuffer[02]:= 16#10;																	(* Fixed *)
		ppBuffer[03]:= pVar.type;															(* Data type (0x01=Single Bit, 0x02=BYTE, 0x04=WORD) *)
		ppBuffer[04]:= DAVgetHIBYTE(pVar.length);							(* Length to read hi-byte *)
		ppBuffer[05]:= DAVgetLOBYTE(pVar.length);							(* Length to read lo-byte *)
		ppBuffer[06]:= DAVgetHIBYTE(pVar.db);									(* DB number hi-byte *)
		ppBuffer[07]:= DAVgetLOBYTE(pVar.db);									(* DB number lo-byte *)			
		ppBuffer[08]:= pVar.area;															(* Area code (0x83=Flags) *)
		ppBuffer[09]:= DAVaddressBITS(pVar.bitAdr, 2);				(* Start address in bits *)
		ppBuffer[10]:= DAVaddressBITS(pVar.bitAdr, 1);				(* Start address in bits (continued) *)
		ppBuffer[11]:= DAVaddressBITS(pVar.bitAdr, 0);				(* Start address in bits (continued) *)

		(* Header TPDU - Update the paramLength as part of the Header TPDU in the Protocol *)
		paramLength:= paramLength + 12;
		pBuffer[DAVpacketReadAddVar + 06]:= DAVgetHIBYTE(paramLength);			(* Parameter length hi-byte *)
		pBuffer[DAVpacketReadAddVar + 07]:= DAVgetLOBYTE(paramLength);			(* Parameter length lo-byte *)

		(* Parameter Area - Increase the number of items in the parameter area *)
		pBuffer[DAVpacketReadAddVar + 11]:= pBuffer[DAVpacketReadAddVar + 11] + 1;	(* Number of items *)			
		
		(* Return the number of bytes in the buffer *)
		DAVpacketReadAddVar:= DAVpacketReadAddVar + 10 + paramLength;	
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketReadAddVar																																																		*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketWriteInit																																																						*)
(*==============================================================================================================================*)
(* Initializes a packet to WRITE multiple variables																																							*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketWriteInit

	(* Create the packetHeader *)
	DAVpacketWriteInit:= DAVpacketHeader(ADR(pDAV), ADR(pBuffer));

	(* Valid header *)
	IF(DAVpacketWriteInit > 0)THEN
	
		(* Header TPDU *)
		pBuffer[DAVpacketWriteInit + 06]:= 16#00;							(* Parameter length hi-byte *)
		pBuffer[DAVpacketWriteInit + 07]:= 16#02;							(* Parameter length lo-byte *)
		pBuffer[DAVpacketWriteInit + 08]:= 16#00;							(* Data length hi-byte *)
		pBuffer[DAVpacketWriteInit + 09]:= 16#00;							(* Data length lo-byte *)
		
		(* Parameter Area *)
		pBuffer[DAVpacketWriteInit + 10]:= 16#05;							(* Function (WRITE) *)
		pBuffer[DAVpacketWriteInit + 11]:= 16#00;							(* Number of items (0) *)
		
		(* Return the number of bytes in the buffer *)
		DAVpacketWriteInit:= DAVpacketWriteInit + 12;					(* ISO/TCP= 19, MPI= 20 *)
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketWriteInit																																																		*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketWriteAddVar																																																					*)
(*==============================================================================================================================*)
(* Adds a variable to a WRITE packet																																														*)
(* Note:																																																												*)
(*			1) The packet length in the ISO/TCP header needs changing.																															*)
(*			2) The parameter length needs changing.																																									*)
(*			3) The data length needs changing.																																											*)
(*			4) The data area needs shifting for the extended parameter area																													*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketWriteAddVar
	
	(* ISO/TCP Protocol *)		
	IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
		packetLength:= DAVmakeWORD(pBuffer[02], pBuffer[03]);
		DAVpacketWriteAddVar:= 7;

	(* MPI Protocol *)
	ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
		DAVpacketWriteAddVar:= 8;

	(* Invalid protocol *)
	ELSE
		DAVpacketWriteAddVar:= 0;
	END_IF


	(* Valid protocol *)
	IF(DAVpacketWriteAddVar > 0)THEN
 		
		(* Update variable address *)
		DAVcalcVARadr(ADR(pVar));

		(* Header TPDU - get the parameter and data lengths *)
		paramLength:= DAVmakeWORD(pBuffer[DAVpacketWriteAddVar + 6], pBuffer[DAVpacketWriteAddVar + 7]);
		dataLength:= DAVmakeWORD(pBuffer[DAVpacketWriteAddVar + 8], pBuffer[DAVpacketWriteAddVar + 9]);

		(* Locate address of start of data area *)
		pBufferData:= ADR(pBuffer) + DAVpacketWriteAddVar + 10 + paramLength;

		(* Data Length must be WORD aligned *)
		IF(dataLength MOD 2 = 1)THEN

			(* Copy a NULL into the data (should be present anyway) *)
			memset(pBufferData + dataLength, 0, 1);

			(* Increase lengths *)
			packetLength:= packetLength + 1;
			dataLength:= dataLength + 1;
		END_IF

		(* Data exists, move it for the new Parameter area *)
		IF(dataLength > 0)THEN

			(* Shift parameter area 12 bytes - for new variable *)
			memmove(pBufferData + 12, pBufferData, dataLength);
			
			(* Clear area - should be overwritten later anyway *)
			memset(pBufferData, 0, 12);
		END_IF
	
	
		(* Update Parameter area with new variable *)
		(* Access memory *)
		ppBuffer ACCESS pBufferData;
		
		(* Parameter Area *)
		ppBuffer[00]:= 16#12;																	(* Fixed *)
		ppBuffer[01]:= 16#0A;																	(* Fixed *)
		ppBuffer[02]:= 16#10;																	(* Fixed *)
		ppBuffer[03]:= pVar.type;															(* Data type (0x01=Single Bit, 0x02=BYTE, 0x04=WORD) *)
		ppBuffer[04]:= DAVgetHIBYTE(pVar.length);							(* Length to read hi-byte *)
		ppBuffer[05]:= DAVgetLOBYTE(pVar.length);							(* Length to read lo-byte *)
		ppBuffer[06]:= DAVgetHIBYTE(pVar.db);									(* DB number hi-byte *)
		ppBuffer[07]:= DAVgetLOBYTE(pVar.db);									(* DB number lo-byte *)			
		ppBuffer[08]:= pVar.area;															(* Area code (0x83=Flags) *)
		ppBuffer[09]:= DAVaddressBITS(pVar.bitAdr, 2);				(* Start address in bits *)
		ppBuffer[10]:= DAVaddressBITS(pVar.bitAdr, 1);				(* Start address in bits (continued) *)
		ppBuffer[11]:= DAVaddressBITS(pVar.bitAdr, 0);				(* Start address in bits (continued) *)


		(* Update Data area with new variable *)
		(* Access memory *)
		ppBuffer ACCESS pBufferData + 12 + dataLength;
		
		(* Data Area *)
		ppBuffer[00]:= 16#00;																	(* Fixed *)
		IF(pVar.type = DAV_VAR_BIT)THEN
			ppBuffer[01]:= 16#03;																(* Bit variable *)
			ppBuffer[02]:= DAVgetHIBYTE(pVar.length);						(* Length to write (in bits) hi-byte *)
			ppBuffer[03]:= DAVgetLOBYTE(pVar.length);						(* Length to write (in bits) lo-byte *)

		ELSE
			ppBuffer[01]:= 16#04;																(* Byte variable *)
			ppBuffer[02]:= DAVgetHIBYTE(pVar.length * 8);				(* Length to write (in bits) hi-byte *)
			ppBuffer[03]:= DAVgetLOBYTE(pVar.length * 8);				(* Length to write (in bits) lo-byte *)
		END_IF


		(* Copy data into ppBuffer. Re-access it (as length may be large) *)
		ppBuffer ACCESS pBufferData + 16 + dataLength;

		(* Swap bytes *)
		(* BYTE - no swapp required *)
		IF(pVar.length = 1)THEN
			ppBuffer[0]:= pWriteBuffer[0];

		(* WORD - swap bytes *)
		ELSIF(pVar.length = 2)THEN
			ppBuffer[0]:= pWriteBuffer[1];
			ppBuffer[1]:= pWriteBuffer[0];

		(* DWORD - swap word and bytes *)
		ELSE
			ppBuffer[0]:= pWriteBuffer[3];
			ppBuffer[1]:= pWriteBuffer[2];
			ppBuffer[2]:= pWriteBuffer[1];
			ppBuffer[3]:= pWriteBuffer[0];			
		END_IF

		
		(* Update packetLengths, paramLength and dataLength *)
		packetLength:= packetLength + 16 + pVar.length;			(* +12 + 4 *)
		paramLength:= paramLength + 12;
		dataLength:= dataLength + 4 + pVar.length;

		(* ISO/TCP Protocol *)
		IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
			pBuffer[02]:= DAVgetHIBYTE(packetLength);					(* Packet length hi-byte *)
			pBuffer[03]:= DAVgetLOBYTE(packetLength);					(* Packet length lo-byte *)
		END_IF
	
		(* Header TPDU *)
		pBuffer[DAVpacketWriteAddVar + 06]:= DAVgetHIBYTE(paramLength);		(* Parameter length hi-byte *)
		pBuffer[DAVpacketWriteAddVar + 07]:= DAVgetLOBYTE(paramLength);		(* Parameter length lo-byte *)
		pBuffer[DAVpacketWriteAddVar + 08]:= DAVgetHIBYTE(dataLength);		(* Data length hi-byte *)
		pBuffer[DAVpacketWriteAddVar + 09]:= DAVgetLOBYTE(dataLength);		(* Data length lo-byte *)

		(* Parameter Area - Increase the number of items in the parameter area *)
		pBuffer[DAVpacketWriteAddVar + 11]:= pBuffer[DAVpacketWriteAddVar + 11] + 1;	(* Number of items *)			
		
		(* Return the number of bytes in the buffer *)
		DAVpacketWriteAddVar:= DAVpacketWriteAddVar + 10 + paramLength + dataLength;
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketWriteAddVar																																																	*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketTCPconnect																																																					*)
(*==============================================================================================================================*)
(* Creates a packet to establish a connection to a PLC via TCP																																	*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketTCPconnect

	(* Packet number *)
	CASE num OF
		
		(* daveConnectPLC (_daveConnectPLCTCP) first packet *)
		(* Establishes a connection to the PLC via TCP *)
		0:
			(* ISO / TCP Protocol *)				
			pBuffer[00]:= 16#03;																	(* Version *)
			pBuffer[01]:= 16#00;																	(* Reserved *)
			pBuffer[02]:= 16#00;																	(* Packet length hi-byte *)
			pBuffer[03]:= 16#16;																	(* Packet length lo-byte *)
					
			(* Header TPDU *)
			pBuffer[04]:= 16#11;																	(* Header length *)
			pBuffer[05]:= 16#E0;																	(* Connect request code *)
			pBuffer[06]:= 16#00;																	(* Destination reference hi-byte *)
			pBuffer[07]:= 16#00;																	(* Destination reference lo-byte *)
			pBuffer[08]:= 16#00;																	(* Source reference hi-byte *)
			pBuffer[09]:= 16#01;																	(* Source reference lo-byte *)
			pBuffer[10]:= 16#00;																	(* Class option (unknown) *)
			pBuffer[11]:= 16#C1;																	(* Parameter code (TSAP-SRC) *)
			pBuffer[12]:= 16#02;																	(* Parameter length *)
			pBuffer[13]:= 16#01;																	(* Calling TSAP hi-byte *)
			pBuffer[14]:= 16#00;																	(* Calling TSAP lo-byte *)
			pBuffer[15]:= 16#C2;																	(* Parameter code (TSAP-DST) *)
			pBuffer[16]:= 16#02;																	(* Parameter length *)
			pBuffer[17]:= pDAV.connection.tcpRack + 1;						(* Calling TSAP hi-byte (Rack number) *)
			pBuffer[18]:= pDAV.connection.tcpSlot;								(* Calling TSAP lo-byte (Slot number) *)
			pBuffer[19]:= 16#C0;																	(* Parameter code (TPDU-Size) *)
			pBuffer[20]:= 16#01;																	(* Parameter length *)
			pBuffer[21]:= 16#09;																	(* TPDU size *)
		
			(* Return the number of bytes in the buffer *)
			DAVpacketTCPconnect:= pBuffer[03];										(* 22; *)


		(* daveConnectPLC (_daveConnectPLCTCP) first packet *)
		(* daveNegPDUlengthRequest - requests the PDU length *)
		1:
			(* ISO / TCP Protocol *)				
			pBuffer[00]:= 16#03;																	(* Version *)
			pBuffer[01]:= 16#00;																	(* Reserved *)
			pBuffer[02]:= 16#00;																	(* Packet length hi-byte *)
			pBuffer[03]:= 16#19;																	(* Packet length lo-byte *)
				
			(* Header TPDU *)
			pBuffer[04]:= 16#02;																	(* Fixed *)
			pBuffer[05]:= 16#F0;																	(* Fixed *)
			pBuffer[06]:= 16#80;																	(* Fixed *)
			pBuffer[07]:= 16#32;																	(* Fixed *)
			pBuffer[08]:= 16#01;																	(* Message type (1) *)
			pBuffer[09]:= 16#00;																	(* Unknown hi-byte *)
			pBuffer[10]:= 16#00;																	(* Unknown lo-bute *)
			pBuffer[11]:= 16#CC;																	(* Sequence number hi-byte *)
			pBuffer[12]:= 16#C1;																	(* Sequence number lo-byte *)
			pBuffer[13]:= 16#00;																	(* Parameter length hi-byte *)
			pBuffer[14]:= 16#08;																	(* Parameter length lo-byte *)
			pBuffer[15]:= 16#00;																	(* Data length hi-byte *)
			pBuffer[16]:= 16#00;																	(* Data length lo-byte *)
	
			(* Parameter Area *)
			pBuffer[17]:= 16#F0;																	(* Fixed *)
			pBuffer[18]:= 16#00;																	(* Fixed *)
			pBuffer[19]:= 16#00;																	(* Fixed *)
			pBuffer[20]:= 16#01;																	(* Fixed *)
			pBuffer[21]:= 16#00;																	(* Fixed *)
			pBuffer[22]:= 16#01;																	(* Fixed *)
			pBuffer[23]:= 16#03;																	(* Fixed *)
			pBuffer[24]:= 16#C0; 																	(* Fixed *)
		
			(* Return the number of bytes in the buffer *)
			DAVpacketTCPconnect:= pBuffer[03];										(* 25; *)


		(* Error - should not occur *)
		ELSE
			DAVpacketTCPconnect:= 0;
	END_CASE	
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketTCPconnect																																																		*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketMPIconnect																																																					*)
(*==============================================================================================================================*)
(* Creates a packet to establish a connection to a PLC via MPI																																	*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketMPIconnect
	
	(* Packet number *)
	CASE num OF
		
		(* daveInitAdapater (_daveInitAdapterMPI1) first packet *)
		(* I think this packet communicates to the MPI adapter to get the adapter version *)
 		0:
			pBuffer[00]:= 16#01;																(* Message *)
			pBuffer[01]:= 16#0D;																(* Message *)
			pBuffer[02]:= 16#02;																(* Message *)

			(* Return the number of bytes in the buffer *)
			DAVpacketMPIconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 3);

		
		(* daveInitAdapater (_daveInitAdapterMPI1) second packet *)
		(* I think this packet communicates to the MPI adapter to get the adapter version *)
		(* It uses a different mechanism to determine if the adapter is "adaoter0300" *)
		1:
			pBuffer[00]:= 16#01;																(* Message *)
			pBuffer[01]:= 16#03;																(* Message *)
			pBuffer[02]:= 16#02;																(* Message *)
			pBuffer[03]:= 16#27;																(* Message *)
			pBuffer[04]:= 16#00;																(* Message *)
			pBuffer[05]:= 16#9F;																(* Message *)
			pBuffer[06]:= 16#01;																(* Message *)
			IF(pDAV.connection.mpiSpeed = DAV_SPEED_500K)THEN
	 			pBuffer[07]:= 16#64;															(* Speed 500k baud *)
	 		ELSIF(pDAV.connection.mpiSpeed = DAV_SPEED_1500K)THEN
				pBuffer[07]:= 16#96;															(* Speed 1500k baud *)
	 		ELSE
				pBuffer[07]:= 16#3C;															(* Default speed 187k baud *)		 	
	 		END_IF
			pBuffer[08]:= 16#00;																(* Message *)
			pBuffer[09]:= 16#90;																(* Message *)
			pBuffer[10]:= 16#01;																(* Message *)
			pBuffer[11]:= 16#14;																(* Message *)
			pBuffer[12]:= 16#00;																(* Message *)
			pBuffer[13]:= 16#00;																(* Message *)
			pBuffer[14]:= 16#05;																(* Message *)
			pBuffer[15]:= pDAV.connection.mpiSpeed; (*16#02;*)	(* MPI speed 187k baud *)
			pBuffer[16]:= pDAV.connection.mpiLocalAdr;					(* Local MPI adr *)
			pBuffer[17]:= 16#1F;																(* Message *)
			pBuffer[18]:= 16#02;																(* Message *)
			pBuffer[19]:= 16#01;																(* Message *)
			pBuffer[20]:= 16#01;																(* Message *)
			pBuffer[21]:= 16#03;																(* Message *)
			pBuffer[22]:= 16#80;																(* Message *)
			
			(* Return the number of bytes in the buffer *)
			DAVpacketMPIconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 23);


		(* daveConnectPLC (_daveConnectPLCMPI1) first packet *)
		(* I think this packet attempts to connect to the required PLC *)
		2:
			pBuffer[00]:= 16#04;																(* Header *)
			pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;	(* PLC MPI address *)
			pBuffer[02]:= 16#80;																(* Header *)
			pBuffer[03]:= 16#0D;																(* Header *)
			pBuffer[04]:= 16#00;																(* Header *)
			pBuffer[05]:= pDAV.connection.connectNum; 					(* Connection number MPI1=0x14, MPI2=0x03 *)
			pBuffer[06]:= 16#E0;																(* Message *)
			pBuffer[07]:= 16#04;																(* Message *)
			pBuffer[08]:= 16#00;																(* Message *)
			pBuffer[09]:= 16#80;																(* Message *)
			pBuffer[10]:= 16#00;																(* Message *)
			pBuffer[11]:= 16#02;																(* Message *)
			pBuffer[12]:= 16#00;																(* Message *)
			pBuffer[13]:= 16#02;																(* Message *)
			pBuffer[14]:= 16#01;																(* Message *)
			pBuffer[15]:= 16#00;																(* Message *)
			pBuffer[16]:= 16#01;																(* Message *)
			pBuffer[17]:= 16#00;																(* Message *)
						
			(* Return the number of bytes in the buffer *)
			DAVpacketMPIconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 18);


		(* daveConnectPLC (_daveConnectPLCMPI1) second packet *)
		(* I think this packet attempts to connect to the required PLC *)
		3:
			pBuffer[00]:= 16#04;																(* Header *)
			pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;	(* PLC MPI address *)
			pBuffer[02]:= 16#80;																(* Header *)
			pBuffer[03]:= 16#0C;																(* Header *)
			pBuffer[04]:= pDAV.connection.connectNum2; 					(* Conenction number 2 16#03 *)
			pBuffer[05]:= pDAV.connection.connectNum;						(* Connection number MPI1=0x14, MPI2=0x03 *)
			pBuffer[06]:= 16#05;																(* Message *)
			pBuffer[07]:= 16#01;																(* Message *)

			(* Return the number of bytes in the buffer *)
			DAVpacketMPIconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 8);


		(* daveConnectPLC (_daveConnectPLCMPI1) thrid packet *)
		(* daveNegPDUlengthRequest - requests the PDU length *)
		4:
			(* Increase PDU number *)
			pDAV.connection.pduNum:= pDAV.connection.pduNum + 1;
		
			pBuffer[00]:= 16#04;																(* Header *)
			pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;	(* MPI address *)
			pBuffer[02]:= 16#80;																(* Header *)
			pBuffer[03]:= 16#0C;																(* Header *)
			pBuffer[04]:= pDAV.connection.connectNum2; 					(* Conenction number 2 16#03 *)
			pBuffer[05]:= pDAV.connection.connectNum;						(* Connection number MPI1=0x14, MPI2=0x03 *)
			pBuffer[06]:= 16#F1;																(* Unknown *)
			pBuffer[07]:= pDAV.connection.msgNum;								(* Message number 16#00 *)
			pBuffer[08]:= 16#32;																(* PDU header *)
			pBuffer[09]:= 16#01;																(* PDU header *)
			pBuffer[10]:= 16#00;																(* PDU header *)
			pBuffer[11]:= 16#00;																(* PDU header *)
			pBuffer[12]:= DAVgetHIBYTE(pDAV.connection.pduNum);	(* Message PDU number *)
			pBuffer[13]:= DAVgetLOBYTE(pDAV.connection.pduNum);	(* Message PDU number *)
			pBuffer[14]:= 16#00;																(* PDU header *)
			pBuffer[15]:= 16#08;																(* PDU header *)
			pBuffer[16]:= 16#00;																(* PDU header *)
			pBuffer[17]:= 16#00;																(* PDU header *)
			pBuffer[18]:= 16#F0;																(* Parameter area *)
			pBuffer[19]:= 16#00;																(* Parameter area *)
			pBuffer[20]:= 16#00;																(* Parameter area *)
			pBuffer[21]:= 16#01;																(* Parameter area *)
			pBuffer[22]:= 16#00;																(* Parameter area *)
			pBuffer[23]:= 16#01;																(* Parameter area *)
			pBuffer[24]:= 16#03;																(* Parameter area *)
			pBuffer[25]:= 16#C0;																(* Parameter area *)

			(* Increase message number *)
			pDAV.connection.ackNum:= pDAV.connection.msgNum;
			IF(pDAV.connection.msgNum = 255)THEN
				pDAV.connection.msgNum:= 1;
			ELSE
				pDAV.connection.msgNum:= pDAV.connection.msgNum + 1;
			END_IF
			
			(* Return the number of bytes in the buffer *)
			DAVpacketMPIconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 26);
		
		(* Error - should not occur *)
		ELSE
			DAVpacketMPIconnect:= 0;
	END_CASE
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketMPIconnect																																																		*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketMPIdisconnect																																																				*)
(*==============================================================================================================================*)
(* Creates a packet to DISCONNECT to the Siemen's PLC																																						*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketMPIdisconnect
	
	(* Packet *)
	CASE num OF
		
		(* daveDisconnectPLC (_daveDisconnectPLCMPI1) first packet *)
		(* A packet to close the communications to the PLC *)
		0:
			pBuffer[00]:= 16#04;																(* Header *)
			pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;	(* PLC MPI address *)
			pBuffer[02]:= 16#80;																(* Header *)
			pBuffer[03]:= 16#0C;																(* Header *)
			pBuffer[04]:= pDAV.connection.connectNum2; 					(* Conenction number 2 16#03 *)
			pBuffer[05]:= pDAV.connection.connectNum;						(* Connection number MPI1=0x14, MPI2=0x03 *)
			pBuffer[06]:= 16#80;																(* Message *)

			(* Return the number of bytes in the buffer *)
			DAVpacketMPIdisconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 7);


		(* daveDisconnectAdapter (_daveDisconnectAdapterMPI) first packet *)
		(* A packet to close the communications to the MPI adapter *)
		1:
			pBuffer[00]:= 16#01;																(* Header *)
			pBuffer[01]:= 16#04;																(* Header *)
			pBuffer[02]:= 16#02;																(* Header *)
			
			(* Return the number of bytes in the buffer *)
			DAVpacketMPIdisconnect:= DAVmpiSuffixCRC(ADR(pBuffer), 3);


		(* Error - should not occur *)
		ELSE
			DAVpacketMPIdisconnect:= 0;
	END_CASE		
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketMPIdisconnect																																																*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVpacketMPIack																																																							*)
(*==============================================================================================================================*)
(* Creates a packet to send an ACK via MPI																																											*)
(* Returns the amount of data in the buffer																																											*)
(********************************************************************************************************************************)
FUNCTION DAVpacketMPIack

	(* Build up packet *)
	pBuffer[00]:= 16#04;																		(* Header *)
	pBuffer[01]:= 16#80 XOR pDAV.connection.mpiPLCAdr;			(* MPI address *)
	pBuffer[02]:= 16#80;																		(* Header *)
	pBuffer[03]:= 16#0C;																		(* Header *)
	pBuffer[04]:= pDAV.connection.connectNum2; 							(* Conenction number 2 16#03 *)
	pBuffer[05]:= pDAV.connection.connectNum;								(* Connection number MPI1=0x14, MPI2=0x03 *)
	pBuffer[06]:= 16#B0;																		(* Message - ACK *)
	pBuffer[07]:= 16#01;																		(* Message *)
	pBuffer[08]:= ackNum;																		(* Send acknowledge number *)

	(* Return the number of bytes in the buffer *)
	DAVpacketMPIack:= DAVmpiSuffixCRC(ADR(pBuffer), 9);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVpacketMPIack																																																				*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVresponseMPIconnect																																																				*)
(*==============================================================================================================================*)
(* Checks the response packet from the Siemen's PLC																																							*)
(* Returns whether the packet is valid																																													*)
(********************************************************************************************************************************)
FUNCTION DAVresponseMPIconnect
	
	(* Packet *)
	CASE num OF
		
		(* daveInitAdapater (_daveInitAdapterMPI1) first packet *)
		(* I think this packet communicates to the MPI adapter to get the adapter version *)
 		0:
			(* Note: the response should be: 											*)
			(*		pBuffer[00] = 16#01 = <SOH>											*)
			(*		pBuffer[01] = 16#0D = <CR>					[allow any] *)
			(*		pBuffer[02] = 16#20 = <SPACE>										*)
			(*		pBuffer[03] = 16#56 = 'V' 											*)
			(*		pBuffer[04] = 16#30 = '0'												*)
			(*		pBuffer[05] = 16#30 = '0'												*)
			(*		pBuffer[06] = 16#2E = '.'												*)
			(*		pBuffer[07] = 16#38 = '8'						[allow any]	*)
			(*		pBuffer[08] = 16#33 = '3'						[allow any]	*)
			(*		pBuffer[09] = 16#10 = <DLE>					[ommit]			*)
			(*		pBuffer[10] = 16#03 = <ETX>					[ommit]			*)
			(*		pBuffer[11] = 16#4C = CHECKSUM 			[ommit]			*)

			DAVresponseMPIconnect:= (pBuffer[00] = 16#01) AND
															(pBuffer[02] = 16#20) AND
															(pBuffer[03] = 16#56) AND
															(pBuffer[04] = 16#30) AND
															(pBuffer[05] = 16#30) AND
															(pBuffer[06] = 16#2E);


		(* daveInitAdapater (_daveInitAdapterMPI1) first packet *)
		(* I think this packet communicates to the MPI adapter to get the adapter version *)
		(* It uses a different mechanism to determine if the adapter is "adaoter0300" *)
 		1:
			(* Note: the response should be: 											*)
			(*		pBuffer[00] = 16#01 = <SOH>											*)
			(*		pBuffer[01] = 16#03 = <ETX>					[allow any] *)
			(*		pBuffer[02] = 16#20 = <SPACE>										*)
			(*		pBuffer[03] = 16#56 = 'V' 											*)
			(*		pBuffer[04] = 16#30 = '0'												*)
			(*		pBuffer[05] = 16#30 = '0'												*)
			(*		pBuffer[06] = 16#2E = '.'												*)
			(*		pBuffer[07] = 16#38 = '8'						[allow any]	*)
			(*		pBuffer[08] = 16#33 = '3'						[allow any]	*)
			(*		pBuffer[09] = 16#10 = <DLE>					[ommit]			*)
			(*		pBuffer[10] = 16#03 = <ETX>					[ommit]			*)
			(*		pBuffer[11] = 16#42 = CHECKSUM 			[ommit]			*)
	
			DAVresponseMPIconnect:= (pBuffer[00] = 16#01) AND
															(pBuffer[02] = 16#20) AND
															(pBuffer[03] = 16#56) AND
															(pBuffer[04] = 16#30) AND
															(pBuffer[05] = 16#30) AND
															(pBuffer[06] = 16#2E);

		
		(* daveConnectPLC (_daveConnectPLCMPI1) first packet *)
		(* I think this packet attempts to connect to the required PLC *)
		2:
			(* Note: the response should be:											*)
			(*		pBuffer[00] = 16#04 = <EOT>											*)
			(*		pBuffer[01] = 16#80 XOR mpiPLCAdr								*)
			(*		pBuffer[02] = 16#80 = extended char	[allow any]	*)
			(*		pBuffer[03] = 16#0C = <FF>											*)
			(*		pBuffer[04] = 16#14 = <DC4>					[allow any]	*)
			(*		pBuffer[05] = 16#03 = <ETX>					[allow any]	*)
			(*		pBuffer[06] = 16#D0 = extended char							*)
			(*		pBuffer[07] = 16#04 = <EOT>											*)
			(*		pBuffer[08] = 16#00 = <NULL>										*)
			(*		pBuffer[09] = 16#80 = extended char							*)
			(*		pBuffer[10] = 16#00 = <NULL>										*)
			(*		pBuffer[11] = 16#02 = <STX>											*)
			(*		pBuffer[12] = 16#00 = <NULL>										*)
			(*		pBuffer[13] = 16#02 = <STX>											*)
			(*		pBuffer[14] = 16#01 = <SOH>											*)
			(*		pBuffer[15] = 16#00 = <NULL>										*)
			(*		pBuffer[16] = 16#01 = <SOH>											*)
			(*		pBuffer[17] = 16#00 = <NULL>										*)
			(*		pBuffer[18] = 16#10 = <DLE>					[ommit]			*)
			(*		pBuffer[19] = 16#03 = <ETX>					[ommit]			*)
			(*		pBuffer[20] = 16#5A = CHECKSUM			[ommit]			*)

			DAVresponseMPIconnect:= (pBuffer[00] = 16#04) AND
															(pBuffer[01] = (16#80 XOR pDAV.connection.mpiPLCAdr)) AND
															(pBuffer[03] = 16#0C) AND
															(pBuffer[06] = 16#D0) AND
															(pBuffer[07] = 16#04) AND
															(pBuffer[08] = 16#00) AND
															(pBuffer[09] = 16#80) AND
															(pBuffer[10] = 16#00) AND
															(pBuffer[11] = 16#02) AND
															(pBuffer[12] = 16#00) AND
															(pBuffer[13] = 16#02) AND
															(pBuffer[14] = 16#01) AND
															(pBuffer[15] = 16#00) AND
															(pBuffer[16] = 16#01) AND
															(pBuffer[17] = 16#00);


		(* daveConnectPLC (_daveConnectPLCMPI1) first packet *)
		(* I think this packet attempts to connect to the required PLC *)
		3:
			(* Note: the response should be: 											*)
			(*		pBuffer[00] = 16#04 = <EOT>											*)
			(*		pBuffer[01] = 16#80 XOR mpiPLCAdr								*)
			(*		pBuffer[02] = 16#80 = extended char	[allow any]	*)
			(*		pBuffer[03] = 16#0C = <FF>											*)
			(*		pBuffer[04] = 16#14 = <DC4>					[allow any]	*)
			(*		pBuffer[05] = 16#03 = <ETX>					[allow any]	*)
			(*		pBuffer[06] = 16#05 = <ENQ>											*)
			(*		pBuffer[07] = 16#01 = <SOH>											*)
			(*		pBuffer[08] = 16#10 = <DLE>					[ommit]			*)
			(*		pBuffer[09] = 16#03 = <ETX>					[ommit]			*)
			(*		pBuffer[10] = 16#0A = CHECKSUM			[ommit]			*)

			DAVresponseMPIconnect:= (pBuffer[00] = 16#04) AND
															(pBuffer[01] = (16#80 XOR pDAV.connection.mpiPLCAdr)) AND
															(pBuffer[03] = 16#0C) AND
															(pBuffer[06] = 16#05) AND
															(pBuffer[07] = 16#01);


		(* Error - should not occur *)
		ELSE
			DAVresponseMPIconnect:= FALSE;
	END_CASE		
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVresponseMPIconnect																																																	*)
(********************************************************************************************************************************)
