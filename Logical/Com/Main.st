
PROGRAM _INIT
	(*Init values*)
	CommunicationStatus := Initializing;
	cmdConnect:= FALSE;
	
	//Init FBK
	DAVInitialize.enable:=            TRUE;               //Enable the function block
	DAVInitialize.pDOConfig:=         ADR('comDAVCfg');   // Name of the configuration data object
	DAVInitialize.pDOMapping:=        ADR('comDAVMap');   // Name of the mapping data object
	DAVInitialize.numItemsConfig:=    0;                  // Maximum number of lines in the configuration data object
	DAVInitialize.numItemsMapping:=   4;                  // Maximum number of lines in the mapping data object
	DAVInitialize();                                      // Service function block
	//##############################################################################################################################
END_PROGRAM

PROGRAM _CYCLIC
	CASE CommunicationStatus OF
		//##############################################################################################################################
		//Initializing communication
		Initializing:
			DAVInitialize(); 
			
			//Error 
			IF (DAVInitialize.status <> 0) AND (DAVInitialize.status <> 65535)  THEN
				CommunicationStatus :=InitializationError;				//Error state
				
			//Initialized
			ELSIF (cmdConnect=TRUE)THEN
				cmdConnect:= FALSE; 								   // Clear flag
				CommunicationStatus :=Connecting;                      // Change state to Connecting
			END_IF
	//##############################################################################################################################
	//Connect to Siemens's PLC
		Connecting:
			DAVConnect.enable:=TRUE;                 					// Enable the function block 
			DAVConnect.pHandle:=DAVInitialize.handle;  					// Configuration handle
			DAVConnect.pMPIinterface:= ADR('IF3');						// Connection mode
			DAVConnect.protocol:=DAV_PROTOCOL_TCP;        				// Serial port to use 
			DAVConnect.pMPIconnection:=ADR(DAV_DEFAULT_MPI);   			// Serial connection
			DAVConnect.MPIspeed:=DAV_SPEED_187K;          				// MPI speed
			DAVConnect.MPIlocalAdr:=0;                     				// MPI local address
			DAVConnect.MPIplcAdr:=2;                     				// MPI plc address
			DAVConnect.pTCPsourceIP:=0;                    				// Source IP address. Use '0' for listenning on all ports
			DAVConnect.pTCPtargetIP:=ADR(strSiemensIP);   				// Siemens IP address to connect to   	
			DAVConnect.TCPport:=DAV_DEFAULT_PORT;        				// Port number to use. Reconnection may use a different port
			DAVConnect.TCPrack:=0;                 						// Siemens rack number
			DAVConnect.TCPslot:=2;              						// Siemens slot number
			DAVConnect.timeout:=DAV_DEFAULT_TIMEOUT;					// Timeout for connection response
			DAVConnect();                            					// Service the function block
			
			//Connected
			IF DAVConnect.status = 0 THEN
				CommunicationStatus := Connected;                       // Change state to Connected and start the client
				
			 //Error 
			ELSIF DAVConnect.status <> 65535 THEN
				CommunicationStatus := ConnectionError; 			//Error state
			END_IF;
	//##############################################################################################################################
	//ISO-on-TCP Client		
		Connected:
			DAVClient.enable:=    TRUE;                     // Enable the function block
			DAVClient.pHandle:=   DAVInitialize.handle;   	// Configuration handle
			DAVClient.pause:=     FALSE;                    // Never pause transmission
			DAVClient.timeout:=   DAV_DEFAULT_TIMEOUT;      // Timeout for connection response
			DAVClient();                                    // Service the function block
			
			//Error 
			IF(DAVClient.status <> 0) AND (DAVClient.status <> 65535)THEN
				CommunicationStatus :=ClientError;       			 // Error state
			END_IF	
			
			//Disconnecting
			IF cmdDisconnect = TRUE THEN
				CommunicationStatus := Disconnecting; 				// Change state to disconnecting
			END_IF;
	//##############################################################################################################################
	//Disconnect from Siemens's PLC
		Disconnecting:
			DAVDisconnect.enable:=    TRUE;                     // Enable the function block
			DAVDisconnect.pHandle:=   DAVInitialize.handle;	  	// Configuration handle
			DAVDisconnect();									// Service the function block
			
			//Disconnected
			IF DAVDisconnect.status = 0 THEN
				CommunicationStatus := Disconected;				// Change state to disconnected
				cmdDisconnect:=FALSE;							// Clear flag
				cmdConnect:=FALSE;								// Clear flag
			
			//Error
			ELSIF DAVDisconnect.status <> 65535 THEN
				CommunicationStatus := DisconnectingError;		//Error State	
			END_IF;
		//##############################################################################################################################
		//Some funny things .... TODO : Reconections Commands AND Errors; 
		Disconected:
			CommunicationStatus := Initializing;
		InitializationError:
			
		ConnectionError:

	END_CASE;
	
END_PROGRAM

PROGRAM _EXIT
	//Disconnect from Siemens's PLC
	DAVDisconnect.enable:=    TRUE;                     // Enable the function block
	DAVDisconnect.pHandle:=   DAVInitialize.handle;	    // Configuration handle
	DAVDisconnect();									// Service the function block
END_PROGRAM	