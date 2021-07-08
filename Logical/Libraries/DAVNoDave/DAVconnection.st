(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVconnection.st																																															*)
(* Author: 				morrisd																																																				*)
(* Created: 			May 26, 2009																																																	*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVconnect																																																										*)
(*==============================================================================================================================*)
(* Creates a connection to the Siemen's PLC		 																																									*)
(* Returns the status and a handle used for the other DAVxx functions																														*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVconnect

	(* Function not enabled *)
	IF(enable = FALSE)THEN	
		status:= 65534;
	
	(* Invalid handle *)
	ELSIF(pHandle = 0)THEN
 		status:= DAV_ERR_HANDLE;
	
	(* Invalid connection *)
	ELSIF((protocol <> DAV_PROTOCOL_TCP) AND (protocol <> DAV_PROTOCOL_MPI))THEN
		status:= DAV_ERR_CONNECT_PROTOCOL;

	(* Invalid interface *)
	ELSIF((protocol = DAV_PROTOCOL_MPI) AND (pMPIinterface = 0))THEN
 		status:= DAV_ERR_CONNECT_INTERFACE;

	(* Invalid IP address *)
	ELSIF((protocol = DAV_PROTOCOL_TCP) AND (pTCPtargetIP = 0))THEN
 		status:= DAV_ERR_CONNECT_TARGETIP;

	(* Run the function *)
	ELSE

		(* Make status busy *)
		status:= 65535;
		
		(****************************************************************************************************************************)
		(* Map data (to avoid errors if the user changes them during operation                  																		*)
		(****************************************************************************************************************************)
		IF(state = 0)THEN

			(* Reset PDU Length *)
			pduLength:= 0;
			portOpened:= 0;
				
			(* Access handle *)
			pDAV ACCESS pHandle;
				
			(* Access buffer *)
			pBufferR ACCESS pDAV.pBufferR;
			memset(pDAV.pBufferR, 0, DAV_DEFAULT_BUFFER_R);

			(* Valid configuration *)
			IF((pDAV.ident = 0) AND (pDAV.connection.protocol = 0) AND
			(pDAV.pBufferR <> 0) AND (pDAV.pBufferW <> 0))THEN
				
				(* Internal *)
				memset(ADR(pDAV.connection), 0, SIZEOF(pDAV.connection));
				pDAV.connection.protocol:=		protocol;									(* Store protocol *)
				pDAV.connection.mpiSpeed:=		MPIspeed;									(* Store MPI speed *)
				pDAV.connection.mpiLocalAdr:=	MPIlocalAdr;							(* Store MPI local address *)
				pDAV.connection.mpiPLCAdr:=		MPIplcAdr;								(* Store MPI PLC address *)
				pDAV.connection.tcpRack:=			TCPrack;									(* Store TCP rack *)
				pDAV.connection.tcpSlot:=			TCPslot;									(* Store TCP slot *)
				pDAV.connection.connectNum:=	16#14;										(* Connection number *)
				pDAV.connection.connectNum2:=	16#03;										(* Connection number 2 (what it should be) *)
				pDAV.connection.pduNum:=			16#FFFE;									(* PDU number *)
				pDAV.connection.msgNum:=			16#00;										(* Message number *)
					
				(* Initialize DAVsend *)
				DAVexchange_0.enable:=				TRUE;											(* Enable function block *)
				DAVexchange_0.pHandle:=				pHandle;									(* Handle from DAVinitialize *)
				DAVexchange_0.sendLength:=		0;												(* Size of sending data - calculated later *)
				DAVexchange_0.mpiFullExchange:=		FALSE;								(* Disable full packet exchange *)
					
				(* Determine timeout *)
				IF(timeout = DAV_DEFAULT_TIMEOUT)THEN
					IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
						DAVexchange_0.timeout:=		150;											(* 1500ms *)
					ELSE
						DAVexchange_0.timeout:=		500;											(* 5000ms *)
					END_IF
				ELSE
					DAVexchange_0.timeout:=			timeout;									(* User's timeout *)
				END_IF

				(* Initialize TCP comms *)
				IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
				
					(* Initialize TcpOpen function block *)
	 				TcpOpen_0.enable:=					TRUE;									(* Enable function block *)
					TcpOpen_0.pIfAddr:= 				pTCPsourceIP;							(* IP Address of port to use *)
					TcpOpen_0.options:= 				0;										(* Default options *)
					
					IF(TcpOpen_0.port = 0)THEN
						TcpOpen_0.port:=					DAV_DEFAULT_SOURCE_PORT;	(* Use an dynamic port (49152 < port < 65535) *)
					ELSE
						TcpOpen_0.port:=					TcpOpen_0.port + 1;				(* Use next port *)
					END_IF
 			
					(* Initialize TcpClient function block *)
	 				TcpClient_0.enable:= 				TRUE;											(* Enable function block *) 
					TcpClient_0.pServer:= 			pTCPtargetIP;							(* Siemens IP Address *)
					IF(TCPport = 0)THEN
						TcpClient_0.portserv:=		DAV_DEFAULT_PORT;					(* Use default port *) 
					ELSE
						TcpClient_0.portserv:=		TCPport;									(* Use users port *)
					END_IF

					(* Initialize TON_10ms function block *)
					TON_10ms_ClientTimeout.IN:=	FALSE;										(* Turn timer off *)
					TON_10ms_ClientTimeout.PT:= 500;											(* 5 seconds timeout *)
					TON_10ms_ClientTimeout();															(* Call function to reset timer *)
					TON_10ms_ClientTimeout.IN:= TRUE;											(* Enable timer *)
		
					(* TCP initialize state *)
					state:= 100;
				
				(* Initialize MPI comms *)
				ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN

					(* Initialize XOPENCONFIG structure *)
					frmConfig.idle:=						4;												(* Idle time between characters: 50ms/38700 = 150 *)
					frmConfig.delimc:=					0;												(* Number of delimiter characters *)
					frmConfig.delim[0]:=				0;												(* Delimiter character *)
					frmConfig.delim[1]:=				0;												(* Delimiter character *)
					frmConfig.tx_cnt:=					2;												(* Number of transmit buffers *)
					frmConfig.rx_cnt:=					2;												(* Number of receive buffers *)
					frmConfig.tx_len:=					DAV_PDU_SIZE + 20;				(* Transmit buffer length *)
					frmConfig.rx_len:=					DAV_PDU_SIZE + 20;				(* Receive buffer length *)
					frmConfig.argc:=						0;												(* Number of additional arguments *)
					frmConfig.argv:=						0;												(* Address of additional arguments *)

					(* Initialize FRM_XOpen function block *)
					FRM_xopen_0.enable:=				TRUE;											(* Enable function block *)
					FRM_xopen_0.device:=				pMPIinterface;						(* Interface to use *)
					IF(pMPIconnection <> 0)THEN
						FRM_xopen_0.mode:= 				pMPIconnection;						(* Users connection parameter *)
					ELSE
						FRM_xopen_0.mode:= 				ADR(DAV_DEFAULT_MPI);			(* Use default connection *)
					END_IF
					FRM_xopen_0.config:= 				ADR(frmConfig);						(* Pointer to configuration *)

					(* MPI initialize state *)
					state:= 200;
				END_IF
				
			(* Connection already open *)
			ELSIF((pDAV.ident <> 0) OR (pDAV.connection.protocol <> 0))THEN
				status:= DAV_ERR_CONNECT_OPEN;
					
			(* Invalid configuration *)
			ELSE
				status:= DAV_ERR_INITIALIZATION;
			END_IF
		END_IF
		(****************************************************************************************************************************)

		
		
		(****************************************************************************************************************************)
		(* Function Operation                                                                     																	*)
		(****************************************************************************************************************************)
		CASE state OF
		
			(**************************************************************************************************************************)
			(* Open Port                                                                            																	*)
			(**************************************************************************************************************************)
			100:
				(* Service function *)
				TcpOpen_0();

				(* Port opened *)
				IF(TcpOpen_0.status = 0)THEN
					pDAV.ident:=							TcpOpen_0.ident;
					TcpClient_0.ident:= 					TcpOpen_0.ident;
					TCPident := 							TcpOpen_0.ident;
					portOpened:=							TcpOpen_0.port;
					state:= 101;
				
				(* Port already open, use next port number *)
				ELSIF(TcpOpen_0.status = tcpERR_ALREADY_EXIST)THEN
					TcpOpen_0.port:= 					TcpOpen_0.port + 1;
					
				(* Error *)
				ELSIF(TcpOpen_0.status <> 65535)THEN
					status:= TcpOpen_0.status;
				END_IF
			(**************************************************************************************************************************)

				
			(**************************************************************************************************************************)
			(* Connect to Siemens PLC                                                               																	*)
			(**************************************************************************************************************************)
			101:
				(* Service function *)
				TcpClient_0();

				(* Service timeout *)
				TON_10ms_ClientTimeout();

				(* Client connected *)
				IF(TcpClient_0.status = 0)THEN
					
					(* Build up packet - connect to PLC *)
					memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);
					DAVexchange_0.sendLength:= DAVpacketTCPconnect(pHandle, pDAV.pBufferW, 0);
					state:= 102;
					
				(* Timeout *)
				ELSIF(TON_10ms_ClientTimeout.Q)THEN
					status:= DAV_ERR_CONNECT_TCP;
	
				(* Error *)
				ELSIF(TcpClient_0.status <> 65535)THEN
					status:= TcpClient_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send connection block and get it's response                                          																	*)
			(**************************************************************************************************************************)
			102:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
					(* Build up packet - get PDU size *)
					memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
					DAVexchange_0.sendLength:= DAVpacketTCPconnect(pHandle, pDAV.pBufferW, 1);
					state:= 103;

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send PDU block and get it's response                                                 																	*)
			(**************************************************************************************************************************)
			103:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
					(* Get PDU Length *)
					memcpy(ADR(pduLength), pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx, 1);

					(* Initialize Client *)
					status:= 0;

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF								
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Open interface												                                                																	*)
			(**************************************************************************************************************************)
			200:
				(* Service function *)
				FRM_xopen_0();

				(* Data sent and received *)
				IF(FRM_xopen_0.status = 0)THEN
					pDAV.ident:= FRM_xopen_0.ident;
					
					(* Build up packet - get MPI adapter version (1) *)
					memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
					DAVexchange_0.sendLength:= DAVpacketMPIconnect(pHandle, pDAV.pBufferW, 0);
					state:= 201;
					
				(* Error *)
				ELSIF(FRM_xopen_0.status <> 65535)THEN
					status:= FRM_xopen_0.status;
				END_IF								
			(**************************************************************************************************************************)

	
			(**************************************************************************************************************************)
			(* Send packet to get the MPI adapter version and get it's response (1)                  																	*)
			(**************************************************************************************************************************)
			201:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN

					(* Check response *)
					IF((DAVexchange_0.recvLength = 12) AND
						(DAVmpiCalcCS(pDAV.pBufferR, DAVexchange_0.recvLength) = TRUE) AND
						(DAVresponseMPIconnect(ADR(pDAV), pDAV.pBufferR, 0) = TRUE))THEN
		 
						(* Build up packet - get MPI adapter version (2) *)
						memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
						DAVexchange_0.sendLength:= DAVpacketMPIconnect(pHandle, pDAV.pBufferW, 1);
						state:= 202;

		 			(* Invalid response *)
		 			ELSE
						status:= DAV_ERR_RECV_RESPONSE;
					END_IF

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send packet to get the MPI adapter version and get it's response (2)                  																	*)
			(**************************************************************************************************************************)
			202:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
					(* Check response *)
					IF((DAVexchange_0.recvLength = 12) AND
						(DAVmpiCalcCS(pDAV.pBufferR, DAVexchange_0.recvLength) = TRUE) AND
						(DAVresponseMPIconnect(ADR(pDAV), pDAV.pBufferR, 1) = TRUE))THEN
		 
						(* Build up packet - connect to PLC (1) *)
						memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
						DAVexchange_0.sendLength:= DAVpacketMPIconnect(pHandle, pDAV.pBufferW, 2);
						state:= 203;

		 			(* Invalid MPI adapter - perhaps adapter0330 *)
					ELSE
						status:= DAV_ERR_MPI_ADAPTER;
					END_IF

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send packet to connect to the PLC and get it's response (1)                          																	*)
			(**************************************************************************************************************************)
			203:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
					(* Check response *)					
					IF((DAVexchange_0.recvLength = 21) AND
						(DAVmpiCalcCS(pDAV.pBufferR, DAVexchange_0.recvLength) = TRUE) AND
						(DAVresponseMPIconnect(ADR(pDAV), pDAV.pBufferR, 2) = TRUE))THEN

						(* Update connection packet *)
						pDAV.connection.connectNum2:= pBufferR[5];

						(* Build up packet - connect to PLC (2) *)
						memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
						DAVexchange_0.sendLength:= DAVpacketMPIconnect(pHandle, pDAV.pBufferW, 3);
						state:= 204;
		
		 			(* Invalid response *)
		 			ELSE
						status:= DAV_ERR_RECV_RESPONSE;
					END_IF

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send packet to connect to the PLC and get it's response (2)                          																	*)
			(**************************************************************************************************************************)
			204:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
						(* Check response *)
					IF((DAVexchange_0.recvLength = 11) AND
						(DAVmpiCalcCS(pDAV.pBufferR, DAVexchange_0.recvLength) = TRUE) AND
						(DAVresponseMPIconnect(ADR(pDAV), pDAV.pBufferR, 3) = TRUE))THEN

						(* Build up packet - get PDU length *)
						memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);					
						DAVexchange_0.sendLength:= DAVpacketMPIconnect(pHandle, pDAV.pBufferW, 4);
						state:= 205;
						
					(* Invalid MPI adapter - perhaps adapter0330 *)
					ELSE
						status:= DAV_ERR_RECV_PROTOCOL;
					END_IF
				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)



			(**************************************************************************************************************************)
			(* Send connection block and get it's response PDU                                         																*)
			(**************************************************************************************************************************)
			205:
				(* Service function *)
				DAVexchange_0.mpiFullExchange:=	TRUE;
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					
					(* Get PDU Length *)
					pduLength:= DAVswapWORD(pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx + 6);

					(* Initialize Client *)
					status:= 0;

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF
			(**************************************************************************************************************************)
		END_CASE

		(* Return to Initialization state *)
		IF(status <> 65535)THEN
			IF(status = 0)THEN
	 			pDAV.internal:= 2;
			END_IF			
			state:= 0;
		END_IF
		(****************************************************************************************************************************)
		(* End of Function Operation                                                              																	*)
		(****************************************************************************************************************************)

	END_IF
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVconnect																																																						*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVdisconnect																																																								*)
(*==============================================================================================================================*)
(* Disconnects the current connection to the Siemen's PLC		 																																		*)
(* Returns the status 																																																					*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVdisconnect
	
	(* Function not enabled *)
	IF(enable = FALSE)THEN
		status:= 65534;
	
	(* Invalid handle *)
	ELSIF(pHandle = 0)THEN
 		status:= DAV_ERR_HANDLE;
	
	(* Run the function *)
	ELSE
	
		(* Make status busy *)
		status:= 65535;
	
		(****************************************************************************************************************************)
		(* Map data (to avoid errors if the user changes them during operation                 																			*)
		(****************************************************************************************************************************)
		IF(state = 0)THEN

			(* Access handle *)
			pDAV ACCESS pHandle;
			
			(* Initialize DAVsend function block *)
			DAVexchange_0.enable:=							TRUE;											(* Enable function block *)
			DAVexchange_0.pHandle:=							pHandle;									(* Handle from DAVinitialize *)
			DAVexchange_0.sendLength:=					0;												(* Size of sending data - calculated later *)
			DAVexchange_0.mpiFullExchange:=			FALSE;										(* Disable full packet exchange *)
					
			(* Determine timeout *)
			IF(timeout = DAV_DEFAULT_TIMEOUT)THEN
				IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
					DAVexchange_0.timeout:=					150;											(* 1500ms *)
				ELSE
					DAVexchange_0.timeout:=					500;											(* 5000ms *)
				END_IF
			ELSE
				DAVexchange_0.timeout:=						timeout;									(* User's timeout *)
			END_IF
			
			(* Create Disconnect packet (0) *)
			memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);
			DAVexchange_0.sendLength:= DAVpacketMPIdisconnect(pHandle, pDAV.pBufferW, 0);
			
			(* Initialize TcpClose function block *)
			TcpClose_0.enable:=							TRUE;											(* Enable function block *)
			TcpClose_0.ident:=							pDAV.ident;										(* TcpOpen ident *)
			TcpClose_0.how:=							0;												(* Close all communcations *)

			(* Initialize FRM_close function block *)
			FRM_close_0.enable:=						TRUE;											(* Enable function block *)
			FRM_close_0.ident:=							pDAV.ident;								(* FRM_Xopen ident *)

			(* Close TCP comms *)
			IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
				state:= 100;

			(* Close MPI comms *)
			ELSIF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
				state:= 200;
	
			(* Invalid mode *)
			ELSE
				status:= DAV_ERR_CONNECT_CLOSED;
			END_IF
		END_IF
		(****************************************************************************************************************************)


		(****************************************************************************************************************************)
		(* Function Operation                                                                     																	*)
		(****************************************************************************************************************************)
		CASE state OF
		
			(**************************************************************************************************************************)
			(* Close Port                                                                            																	*)
			(**************************************************************************************************************************)
			100:
				(* Service function *)
				TcpClose_0();
	
				(* Port opened *)
				IF(TcpClose_0.status = 0)THEN
					status:= 0;
				
				(* Error *)
				ELSIF(TcpClose_0.status <> 65535)THEN
					status:= TcpClose_0.status;
				END_IF
			(**************************************************************************************************************************)

			
			(**************************************************************************************************************************)
			(* Disconnect from the PLC                                                              																	*)
			(**************************************************************************************************************************)
			200:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN

					(* Create Disconnect packet (0) *)
					memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);
					DAVexchange_0.sendLength:= DAVpacketMPIdisconnect(pHandle, pDAV.pBufferW, 1);
					state:= 201;

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF

			(**************************************************************************************************************************)
	
			
			(**************************************************************************************************************************)
			(* Disconnect from the MPI Adapter                                                       																	*)
			(**************************************************************************************************************************)
			201:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
					state:= 202;

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF

			(**************************************************************************************************************************)
	
			
			(**************************************************************************************************************************)
			(* Close Port                                                                            																	*)
			(**************************************************************************************************************************)
			202:
				(* Service function *)
				FRM_close_0();
	
				(* Port opened *)
				IF(FRM_close_0.status = 0)THEN
					status:= 0;
				
				(* Error *)
				ELSIF(FRM_close_0.status <> 65535)THEN
					status:= FRM_close_0.status;
				END_IF
			(**************************************************************************************************************************)
		END_CASE

		(* Return to Initialization state *)
		IF(status <> 65535)THEN
		
			(* Reconnection required *)
			IF(status = 0)THEN
				IF(pDAV.internal > 1)THEN
	 				pDAV.internal:= 1;
				END_IF
				pDAV.ident:= 0;
				memset(ADR(pDAV.connection), 0, SIZEOF(pDAV.connection));
			END_IF
			state:= 0;
		END_IF
		(****************************************************************************************************************************)
		(* End of Function Operation                                                               																	*)
		(****************************************************************************************************************************)
	END_IF
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVdisconnect																																																					*)
(********************************************************************************************************************************)
