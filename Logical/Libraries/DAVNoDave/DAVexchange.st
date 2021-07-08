(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVexchange.st																																																*)
(* Author: 				morrisd																																																				*)
(* Created: 			May 26, 2009																																																	*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVexchange																																																									*)
(*==============================================================================================================================*)
(* Sends a packet to the PLC									 																																									*)
(* Receives the response from the PLC 																																													*)
(* Returns a status																																																							*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVexchange

	(* Function not enabled *)
	IF(enable = FALSE)THEN	
		status:= 65534;
	
	(* Invalid handle *)
	ELSIF(pHandle = 0)THEN
 		status:= DAV_ERR_HANDLE;

	(* Invalid buffer length *)
	ELSIF((sendLength = 0) OR (sendLength > DAV_DEFAULT_BUFFER_W))THEN
 		status:= DAV_ERR_BUFFER_SIZE;

	(* Run the function *)
	ELSE

		(* Make status busy *)
		status:= 65535;
		
		(****************************************************************************************************************************)
		(* Map data (to avoid errors if the user changes them during operation                  																		*)
		(* Note: code placed here to avoid a 1 scan delay																																						*)
		(****************************************************************************************************************************)
		IF(state = 0)THEN

			(* Reset received number of bytes *)
			recvLength:= 					0;
			recvParamLength:= 		0;
			recvDataLength:= 			0;
			recvStartOfDataIdx:=	0;
			
			(* Access handle *)
			pDAV ACCESS pHandle;
			
			(* Access buffer *)
			ppBuffer ACCESS pDAV.pBufferR;
			memset(pDAV.pBufferR, 0, DAV_DEFAULT_BUFFER_R);
			
			(* Initialize TON timeout function block *)
			TON_10ms_Timeout.IN:=					FALSE;									(* Turn timer off *)
			IF((timeout = 0) AND (pDAV.connection.protocol = DAV_PROTOCOL_TCP))THEN
				TON_10ms_Timeout.PT:=				150;										(* Default TCP tiemout = 1.5s *)
			ELSIF(timeout = 0)THEN
				TON_10ms_Timeout.PT:=				500;										(* Default MPI tiemout = 5s *)
			ELSE
				TON_10ms_Timeout.PT:= 			timeout;								(* User's timeout *)
			END_IF
			TON_10ms_Timeout();																		(* Call function to reset timer *)
			TON_10ms_Timeout.IN:= 				TRUE;										(* Enable timer *)

			(* Initialize TCP coms *)
			IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN

				(* Initialize TcpSend function block *)
				TcpSend_0.enable:=					TRUE;										(* Enable function block *)
				TcpSend_0.ident:=						pDAV.ident;							(* TcpOpen ident *)
				TcpSend_0.pData:=						pDAV.pBufferW;					(* Address of write buffer *) 
				TcpSend_0.datalen:=					sendLength;							(* Length of data to send *)
				TcpSend_0.flags:=						0;											(* Default options *) 

				(* Initialize TcpSend function block *)
				TcpRecv_0.enable:=					TRUE;										(* Enable function block *)
				TcpRecv_0.ident:=						pDAV.ident;							(* TcpOpen ident *)
				TcpRecv_0.pData:=						pDAV.pBufferR;					(* Address of read buffer *)
				TcpRecv_0.datamax:=				 	DAV_DEFAULT_BUFFER_R;		(* Size of read buffer *)
				TcpRecv_0.flags:= 					0;											(* Default options *)
			
				(* Go to next state *)
				state:= 100;
			
			(* Initialize MPI coms *)
			ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
	 			
				(* Initialize DAVmpiSend function block *)
				DAVmpiSend_0.enable:=				TRUE;										(* Enable function block *)
				DAVmpiSend_0.ident:=				pDAV.ident;							(* FRM_Xopen ident *)
				DAVmpiSend_0.pBufferW:=			ADR(bufferSend);				(* Default to internal buffer *)
				DAVmpiSend_0.sendLength:=		0;											(* Clear send length (will change) *)

				(* Initialize DAVmpiRead function block *)
				DAVmpiRead_0.enable:=				TRUE;										(* Enable function block *)
				DAVmpiRead_0.ident:=				pDAV.ident;							(* FRM_Xopen ident *)
				DAVmpiRead_0.pBufferR:=			ADR(bufferRead);				(* Default to internal buffer *)
				DAVmpiRead_0.readLength:=		SIZEOF(bufferRead);			(* Size of read buffer *)

				(* Clear buffers *)
				memset(ADR(bufferSend), 0, SIZEOF(bufferSend));
				memset(ADR(bufferRead), 0, SIZEOF(bufferRead));
				
				(* Initialize STATE 200 *)
				bufferSend[0]:=							16#02;									(* STX *)
				DAVmpiSend_0.sendLength:=		1;											(* Length to send *)

				(* Go to next state *)
				state:= 200;
				
			(* Invalid mode *)
			ELSE
				status:= DAV_ERR_CONNECT_PROTOCOL;
			END_IF
		END_IF
		(****************************************************************************************************************************)
		
		
		(****************************************************************************************************************************)
		(* Function Operation                                                                     																	*)
		(****************************************************************************************************************************)
		CASE state OF
			
			(**************************************************************************************************************************)
			(* TCP Write - message                                                                   																	*)
			(**************************************************************************************************************************)
			100:
				(* Service function *)
				TcpSend_0();
				
				(* Data sent *)
				IF((TcpSend_0.status = 0) AND (TcpSend_0.sentlen = TcpSend_0.datalen))THEN
		 				state:= 101;
				
				(* Not all the data was sent *)
				ELSIF(TcpSend_0.status = 0)THEN
					status:= DAV_ERR_SEND_MISSINGDATA;
					
				(* Error *)
				ELSIF(TcpSend_0.status <> 65535)THEN
					status:= TcpSend_0.status;
				END_IF												
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* TCP Read - message                                                                    																	*)
			(**************************************************************************************************************************)
			101:
				(* Service function *)
				TcpRecv_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();
				
				(* Data received *)
				IF((TcpRecv_0.status = 0) AND (TcpRecv_0.recvlen > 0))THEN
					recvLength:= DAVswapWORD(ADR(ppBuffer[2]));								(* Bytes ppBuffer[2] and [3] *)
	
					(* Not all the data has been received *)
					IF(recvLength <> UDINT_TO_UINT(TcpRecv_0.recvlen))THEN
				 		recvLength:= UDINT_TO_UINT(TcpRecv_0.recvlen);
				 		status:= DAV_ERR_RECV_MISSINGDATA;
						
				 	(* Complete *)
				 	ELSE
						(* Return Parameter and Data lengths *)
						recvParamLength:= DAVswapWORD(ADR(ppBuffer[13]));				(* Bytes ppBuffer[13] and [14] *)
						recvDataLength:= DAVswapWORD(ADR(ppBuffer[15]));				(* Bytes ppBuffer[15] and [16] *)
							
						(* Return the start of the data index *)
						IF((ppBuffer[8] = 2) OR (ppBuffer[8] = 3))THEN
							recvStartOfDataIdx:= 19; (*7 + 12;*)
						ELSE
							recvStartOfDataIdx:= 17; (*7 + 10;*)
						END_IF	

						(* Reduce receive length for length of data *)
						IF(recvLength >= recvStartOfDataIdx)THEN
		 					recvLength:= recvLength - recvStartOfDataIdx;
						ELSE
							recvLength:= 0;
						END_IF
						status:= 0;
					END_IF

				(* Invalid receive length *)				
				ELSIF(TcpRecv_0.status = 0)THEN
					status:= DAV_ERR_RECV_NODATA;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* No data - try again *)
				ELSIF(TcpRecv_0.status = tcpERR_NO_DATA)THEN
					state:= state;
				
				(* Error *)
				ELSIF(TcpRecv_0.status <> 65535)THEN
					status:= TcpRecv_0.status;
				END_IF
			(**************************************************************************************************************************)
			
			
			(**************************************************************************************************************************)
			(* MPI Write - STX		                                                                   																	*)
			(**************************************************************************************************************************)
			200:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
			 		bufferSend[0]:= 0;
					state:= 201;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - DLE                                                               																					*)
			(**************************************************************************************************************************)
			201:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received - DLE *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#10))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
					
					(* Point to the message buffer *)
					DAVmpiSend_0.pBufferW:=			pDAV.pBufferW;
					DAVmpiSend_0.sendLength:=		sendLength;

					(* Continue *)
					bufferRead[0]:= 0;
					state:= 202;

				(* Invalid data *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Write - message                                                                   																	*)
			(**************************************************************************************************************************)
			202:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN

					(* Point to the internal buffer *)
					DAVmpiSend_0.pBufferW:= ADR(bufferSend);
			 		state:= 203;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - DLE | DLE + STX                                                    																					*)
			(**************************************************************************************************************************)
			203:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND ( 
					((DAVmpiRead_0.recvBufferLength = 2) AND (bufferRead[0] = 16#10) AND (bufferRead[1] = 16#02)) OR
					((DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#10)) ))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
				
		 			(* Valid data - DLE STX *)
					bufferRead[0]:= 0;
					IF(DAVmpiRead_0.recvBufferLength = 2)THEN
						bufferRead[1]:= 0;
		 				state:= 205;
		 			
					(* Valid data - DLE *)
					ELSE
						state:= 204;
					END_IF

				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Read - STX					                                                               																	*)
			(**************************************************************************************************************************)
			204:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#02))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
					
					(* Create message to send *)
					bufferSend[0]:= 						16#10;								(* DLE *)
					DAVmpiSend_0.sendLength:=		1;										(* Length to send *)

					(* Continue *)
					bufferRead[0]:= 0;
					state:= 205;

				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Write - DLE		                                                                   																	*)
			(**************************************************************************************************************************)
			205:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
			 		
					(* Point to the message buffer *)
					IF(mpiFullExchange = FALSE)THEN
						DAVmpiRead_0.pBufferR:=			pDAV.pBufferR;
						DAVmpiRead_0.readLength:=		DAV_DEFAULT_BUFFER_R;
 					END_IF

					(* Continue *)
					bufferSend[0]:= 0;
					state:= 206;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - message / ack			                                                         																	*)
			(**************************************************************************************************************************)
			206:
				(* Service function *)
	      DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength > 0))THEN

					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
					
					(* Point to the internal buffer *)
					DAVmpiRead_0.pBufferR:=			ADR(bufferRead);
					DAVmpiRead_0.readLength:=		SIZEOF(bufferRead);
			
					(* Create message to send *)
					bufferSend[0]:= 						16#10;									(* DLE *)
					DAVmpiSend_0.sendLength:=		1;

		 			(* Return received length *)
					IF(mpiFullExchange = FALSE)THEN
						recvLength:= DAVmpiRead_0.recvBufferLength;
					END_IF
					state:= 207;
					
				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;
					
				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Write - DLE		                                                                   																	*)
			(**************************************************************************************************************************)
			207:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
					bufferSend[0]:= 0;

					(* Complete *)
					IF(mpiFullExchange = FALSE)THEN
						status:= 0;
					
					(* Check for a valid ACK *)
					(*	1) Length is 12 *)
					(*	2) Position 6 contains 16#B0 - used for an acknowledge *)
					(*	3) Position 8 contains the required acknowledge number *)
					ELSE

						(* Remove DLE doubling *)
						recvLength:= DAVdecodeMPI(ADR(bufferRead), SIZEOF(bufferRead), DAVmpiRead_0.recvBufferLength);
						IF((recvLength = 12) AND (bufferRead[6] = 16#B0) AND (bufferRead[8] = pDAV.connection.ackNum))THEN
					
							(* Store acknowledge number to send *)
							sendAckNumber:= bufferRead[7];
							memset(ADR(bufferRead), 0, SIZEOF(bufferRead));
							state:= 208;
	
						(* Invalid ACK packet *)
						ELSE
			 				status:= DAV_ERR_ACKNOWLEDGE;						
						END_IF
					END_IF
					
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - STX					                                                               																	*)
			(**************************************************************************************************************************)
			208:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#02))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
					
					(* Create message to send *)
					bufferSend[0]:= 						16#10;								(* DLE *)
					DAVmpiSend_0.sendLength:=		1;										(* Length to send *)

					(* Continue *)
					bufferRead[0]:= 0;
					state:= 209;

				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Write - DLE		                                                                   																	*)
			(**************************************************************************************************************************)
			209:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
			 		
					(* Point to the message buffer *)
					memset(pDAV.pBufferR, 0, DAV_DEFAULT_BUFFER_R);
					DAVmpiRead_0.pBufferR:=			pDAV.pBufferR;
					DAVmpiRead_0.readLength:=		DAV_DEFAULT_BUFFER_R;
 
					(* Continue *)
					bufferSend[0]:= 0;
					state:= 210;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - message			                                                         																						*)
			(**************************************************************************************************************************)
			210:
				(* Service function *)
	      DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength > 0))THEN

					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
					
					(* Point to the internal buffer *)
					DAVmpiRead_0.pBufferR:=			ADR(bufferRead);
					DAVmpiRead_0.readLength:=		SIZEOF(bufferRead);
			
					(* Create message to send *)
					bufferSend[0]:= 						16#10;									(* DLE *)
					DAVmpiSend_0.sendLength:=		1;
					
					(* Store acknowledge number to send *)
					sendAckNumber:= ppBuffer[7];
		 			
					(* Return received length *)
					recvLength:= DAVmpiRead_0.recvBufferLength;
					state:= 211;
					
				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;
					
				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Write - DLE			                                                                 																	*)
			(**************************************************************************************************************************)
			211:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
 
					(* Create message to send *)
					bufferSend[0]:= 						16#02;									(* STX *)
					DAVmpiSend_0.sendLength:=		1;
					state:= 212;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Write - STX                                                                  																			*)
			(**************************************************************************************************************************)
			212:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
 
					(* Continue *)
					bufferSend[0]:= 0;
					state:= 213;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - DLE                                                               																					*)
			(**************************************************************************************************************************)
			213:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#10))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
				
					(* Create message to send *)
					DAVmpiSend_0.sendLength:= DAVpacketMPIack(ADR(pDAV), ADR(bufferSend), sendAckNumber);

		 			(* Continue *)
					bufferRead[0]:= 0;
	 				state:= 214;

				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	


			(**************************************************************************************************************************)
			(* MPI Write - ack		                                                                   																	*)
			(**************************************************************************************************************************)
			214:
				(* Service function *)
				DAVmpiSend_0();
				
				(* Data written *)
				IF(DAVmpiSend_0.status = 0)THEN
					memset(ADR(bufferSend), 0, SIZEOF(bufferSend));
			 		state:= 215;
						
				(* Error writing data *)
				ELSIF(DAVmpiSend_0.status <> 65535)THEN
					status:= DAVmpiSend_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* MPI Read - DLE                                                               																					*)
			(**************************************************************************************************************************)
			215:
				(* Service function *)
        DAVmpiRead_0();
				
				(* Service timeout *)
				TON_10ms_Timeout();

				(* Data received *)
				IF((DAVmpiRead_0.status = 0) AND (DAVmpiRead_0.recvBufferLength = 1) AND (bufferRead[0] = 16#10))THEN
					
					(* Reset timer *)
					TON_10ms_Timeout.IN:= FALSE;
					TON_10ms_Timeout();
					TON_10ms_Timeout.IN:= TRUE;
				
		 			(* Internal *)
					bufferRead[0]:= 0;
					status:= 0;
					
					(* Remove DLE doubling *)
					recvLength:= DAVdecodeMPI(pDAV.pBufferR, DAV_DEFAULT_BUFFER_R, recvLength);

					(* Return Parameter and Data lengths *)
					recvParamLength:= DAVswapWORD(ADR(ppBuffer[14]));				(* Bytes ppBuffer[14] and [15] *)
					recvDataLength:= DAVswapWORD(ADR(ppBuffer[16]));				(* Bytes ppBuffer[16] and [17] *)
							
					(* Return the start of the data index *)
					IF((ppBuffer[9] = 2) OR (ppBuffer[9] = 3))THEN
						recvStartOfDataIdx:= 20; (*8 + 12;*)
					ELSE
						recvStartOfDataIdx:= 18; (*8 + 10;*)
					END_IF	

					(* Reduce receive length for length of data *)
					IF(recvLength >= recvStartOfDataIdx)THEN
		 				recvLength:= recvLength - recvStartOfDataIdx;
					ELSE
						recvLength:= 0;
					END_IF		

				(* Invalid protocol *)
				ELSIF(DAVmpiRead_0.status = 0)THEN
					status:= DAV_ERR_RECV_PROTOCOL;

				(* Timeout *)
				ELSIF(TON_10ms_Timeout.Q)THEN
					status:= DAV_ERR_TIMEOUT;

				(* Error *)
				ELSIF(DAVmpiRead_0.status <> 65535)THEN
					status:= DAVmpiRead_0.status;
				END_IF
			(**************************************************************************************************************************)	

		END_CASE
		(****************************************************************************************************************************)
		(* End of Function Operation                                                              																	*)
		(****************************************************************************************************************************)
	
		
		(****************************************************************************************************************************)
		(* Reset to state 0 when complete	(or in error)																																							*)
		(****************************************************************************************************************************)
		IF(status <> 65535)THEN
			lastState:= state;
			state:= 0;
		END_IF		
		(****************************************************************************************************************************)

	END_IF
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVsend																																																								*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVmpiSend																																																										*)
(*==============================================================================================================================*)
(* Write data to a Siemen's PLC			 																																														*)
(* Returns a status																																																							*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVmpiSend

	(* Function not enabled *)
	IF(enable = FALSE)THEN
		status:= 65534;

	(* Invalid buffer pointer *)
	ELSIF(pBufferW = 0)THEN
 		status:= DAV_ERR_BUFFER;

	(* Invalid length *)
	ELSIF(sendLength = 0)THEN
 		status:= DAV_ERR_SEND_NODATA;

	(* Run the function *)
	ELSE
		
		(* Make function status busy *)
		status:= 65535;

		(* Service function *)
		FRM_gbuf_0.enable:=					TRUE;										(* Enable function block *)
		FRM_gbuf_0.ident:=					ident;									(* FRM_Xopen ident *)
		FRM_gbuf_0();

		(* Buffer available *)
		IF((FRM_gbuf_0.status = 0) AND (FRM_gbuf_0.buffer <> 0) AND (FRM_gbuf_0.buflng >= sendLength))THEN
						
			(* Store data to write *)
			IF(FRM_gbuf_0.buflng > sendLength)THEN
				memcpy(FRM_gbuf_0.buffer, pBufferW, sendLength);
			ELSE
				memcpy(FRM_gbuf_0.buffer, pBufferW, FRM_gbuf_0.buflng);
			END_IF

			(* Service function *)
			FRM_write_0.enable:=			TRUE;										(* Enable function block *)
			FRM_write_0.ident:=				ident;									(* FRM_Xopen ident *)
			FRM_write_0.buffer:=			FRM_gbuf_0.buffer;			(* Write buffer *)
			FRM_write_0.buflng:= 			sendLength;							(* Write buffer length *)
			FRM_write_0();																		(* Service the function block *)
				
			(* Data written *)
			IF(FRM_write_0.status = 0)THEN
				status:= 0;
						
			(* Error writing data *)
			ELSE
				status:= FRM_write_0.status;
						
				(* Manually release buffer *)
				FRM_robuf_0.enable:= 		TRUE;										(* Enable function block *)
				FRM_robuf_0.ident:=			ident;									(* FRM_Xopen ident *)
				FRM_robuf_0.buffer:=		FRM_gbuf_0.buffer;			(* Write buffer *)
				FRM_robuf_0.buflng:=		FRM_gbuf_0.buflng;			(* Write buffer length *)
				FRM_robuf_0();
			END_IF

		(* Buffer not large enough *)
		ELSIF(FRM_gbuf_0.status = 0)THEN
			status:= DAV_ERR_SEND_BUFFERSIZE;

		(* Error *)
		ELSIF(FRM_gbuf_0.status <> 65535)THEN
			status:= FRM_gbuf_0.status;
		END_IF
	END_IF
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVmpiSend																																																						*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVmpiRead																																																										*)
(*==============================================================================================================================*)
(* Reads data to a Siemen's PLC			 																																														*)
(* Returns a status																																																							*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVmpiRead

	(* Clear received buffer length *)
	recvBufferLength:= 0;

	(* Function not enabled *)
	IF(enable = FALSE)THEN
		status:= 65534;

	(* Invalid buffer pointer *)
	ELSIF(pBufferR = 0)THEN
 		status:= DAV_ERR_BUFFER;

	(* Invalid length *)
	ELSIF(readLength = 0)THEN
 		status:= DAV_ERR_BUFFER_SIZE;

	(* Run the function *)
	ELSE
		
		(* Make function status busy *)
		status:= 65535;

		(* Service function *)
		FRM_read_0.enable:=			TRUE;										(* Enable function block *)
		FRM_read_0.ident:=			ident;									(* FRM_Xopen ident *)
 		FRM_read_0();

		(* Data received *)
		IF((FRM_read_0.status = 0) AND (FRM_read_0.buflng > 0) AND (FRM_read_0.buffer <> 0))THEN
			
			(* Copy data *)
			IF(FRM_read_0.buflng <= readLength)THEN
				memset(pBufferR, 0, readLength);						(* Clear data *)
				memcpy(pBufferR, FRM_read_0.buffer, FRM_read_0.buflng);
				recvBufferLength:= FRM_read_0.buflng;				(* Buffer length *)
			
			(* Buffer too small *)
			ELSE
				status:= DAV_ERR_RECV_BUFFERSIZE;
			END_IF
					
			(* Release the read buffer *)
			FRM_rbuf_0.enable:=		TRUE;										(* Read buffer *)
			FRM_rbuf_0.ident:=		ident;									(* Read buffer length *)
			FRM_rbuf_0.buffer:= 	FRM_read_0.buffer;			(* Read buffer *)
			FRM_rbuf_0.buflng:= 	FRM_read_0.buflng;			(* Read buffer length *)
			FRM_rbuf_0();																	(* Service the function block *)												

			(* Buffer released *)
			IF(FRM_rbuf_0.status <> 0)THEN
				status:= FRM_rbuf_0.status;	

			(* Function complete *)
			ELSIF(status = 65535)THEN
				status:= 0;
			END_IF
					
		(* Invalid receive length *)				
		ELSIF(FRM_read_0.status = 0)THEN
			status:= DAV_ERR_RECV_NODATA;

		(* No data - try again *)
		ELSIF(FRM_read_0.status = frmERR_NOINPUT)THEN
			status:= 65535;
				
		(* Error *)
		ELSIF(FRM_read_0.status <> 65535)THEN
			status:= FRM_read_0.status;
		END_IF
	END_IF
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVmpiRead																																																						*)
(********************************************************************************************************************************)
