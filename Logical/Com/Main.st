
PROGRAM _INIT
	(*Init values*)
	CommunicationStatus := Initializing;
	cmdConnect:= FALSE;
	
	(* Init FBK *)
	DAVInitialize.enable:=            TRUE;               (* Enable the function block *)
	DAVInitialize.pDOConfig:=         ADR('comDAVCfg');   (* Name of the configuration data object *)
	DAVInitialize.pDOMapping:=        ADR('comDAVMap');   (* Name of the mapping data object *)
	DAVInitialize.numItemsConfig:=    0;                 (* Maximum number of lines in the configuration data object *)
	DAVInitialize.numItemsMapping:=   4;                 (* Maximum number of lines in the mapping data object *)
	DAVInitialize();                                      (* Service function block *)
	(*-----------------------------------------------------*)
END_PROGRAM

PROGRAM _CYCLIC
	CASE CommunicationStatus OF
		(*Initializing communication*)
		Initializing:
			
			DAVInitialize(); 
			
			IF (DAVInitialize.status <> 0) AND (DAVInitialize.status <> 65535)  THEN
				CommunicationStatus :=InitializationError;
				
			ELSIF (cmdConnect=TRUE)THEN
				cmdConnect:= FALSE; 
				CommunicationStatus :=Connecting;
			END_IF
		(*-----------------------------------------------------*)
		Connecting:
			(*Connect to Siemens's PLC *)
			DAVConnect.enable:=TRUE;       //              		
			DAVConnect.pHandle:=DAVInitialize.handle;  //
			DAVConnect.pMPIinterface:= ADR('IF3');		//		
			DAVConnect.protocol:=DAV_PROTOCOL_TCP;        // 					
			DAVConnect.pMPIconnection:=ADR(DAV_DEFAULT_MPI); //   
			DAVConnect.MPIspeed:=DAV_SPEED_187K; //          		
			DAVConnect.MPIlocalAdr:=0; //                       
			DAVConnect.MPIplcAdr:=2;   //                   	
			DAVConnect.pTCPsourceIP:=0;  //                     	
			DAVConnect.pTCPtargetIP:=ADR(strSiemensIP); //      	
			DAVConnect.TCPport:=DAV_DEFAULT_PORT; //        		
			DAVConnect.TCPrack:=0;      //                  		
			DAVConnect.TCPslot:=2;        //                		
			DAVConnect.timeout:=DAV_DEFAULT_TIMEOUT; // 			
			DAVConnect();         //                              
			
			IF DAVConnect.status = 0 THEN
				CommunicationStatus := Connected;
				
			ELSIF DAVConnect.status <> 65535 THEN
				CommunicationStatus := ConnectionError;
			END_IF;
		(*-----------------------------------------------------*)			
		Connected:
		(*ISO-on_TCP Client*)
			DAVClient.enable:=    TRUE;                     (* Enable the function block *)
			DAVClient.pHandle:=   DAVInitialize.handle;   (* Configuration handle *)
			DAVClient.pause:=     FALSE;                    (* Never pause transmission *)
			DAVClient.timeout:=   DAV_DEFAULT_TIMEOUT;      (* Timeout for connection response *)
			DAVClient();                                    (* Service the function block *)
			
			IF(DAVClient.status <> 0) AND (DAVClient.status <> 65535)THEN
				CommunicationStatus :=ClientError;        (* Error state *)
			END_IF	
			
			IF cmdDisconnect = TRUE THEN
				CommunicationStatus := Disconnecting;
			END_IF;
		(*-----------------------------------------------------*)
		Disconnecting:
		(*Disconnect from Siemens's PLC*)
			DAVDisconnect.enable:=    TRUE;                     (* Enable the function block *)
			DAVDisconnect.pHandle:=   DAVInitialize.handle;	  (* Configuration handle *)
			DAVDisconnect();
			
			IF DAVDisconnect.status = 0 THEN
				CommunicationStatus := Disconected;
				cmdDisconnect:=FALSE;
				cmdConnect:=FALSE;
				
			ELSIF DAVDisconnect.status <> 65535 THEN
				CommunicationStatus := DisconnectingError;
			END_IF;
		(*-----------------------------------------------------*)
		Disconected:
			CommunicationStatus := Initializing;
		InitializationError:
			
		ConnectionError:

	END_CASE;
	
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	DAVDisconnect.enable:=    TRUE;                     (* Enable the function block *)
	DAVDisconnect.pHandle:=   DAVInitialize.handle;	  (* Configuration handle *)
	DAVDisconnect();
END_PROGRAM