(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVclient.st																																																	*)
(* Author: 				morrisd																																																				*)
(* Created: 			June 02, 2009																																																	*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVclient																																																										*)
(*==============================================================================================================================*)
(* Services communications between the PLC and the Siemen's PLC																																	*)
(* Returns a status																																																							*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVclient
	
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
		(* Initialize function																									                  																	*)
		(****************************************************************************************************************************)
		IF(state = 0)THEN
			pDAV ACCESS pHandle;																	(* Access handle *)

			(* Valid configuration 0 *)
			IF(pDAV.internal = 2)THEN							
				pDAV.internal:= 3;
				
				(* Initialize DAVsend *)
				memset(ADR(DAVexchange_0), 0, SIZEOF(DAVexchange_0));
				DAVexchange_0.enable:=						TRUE;							(* Enable function block *)
				DAVexchange_0.pHandle:=						pHandle;					(* Handle from DAVinitialize *)
				DAVexchange_0.sendLength:=				0;								(* Size of sending data - calculated later *)
				DAVexchange_0.timeout:=						timeout;					(* Pass timeout *)
				DAVexchange_0.mpiFullExchange:=	 TRUE;							(* Enable full exchange of data *)

				(* Check initialization *)
				IF((pDAV.pBufferR <> 0) AND (pDAV.pBufferW <> 0) AND (pDAV.pConfig <> 0) AND (pDAV.pMapping <> 0) AND (pDAV.maxLinesMapping > 0))THEN
				
					(* Clear the internal variables *)
					IF(pDAV.maxLinesConfig > 0)THEN
						FOR itemIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (itemIdx * SIZEOF(pConfig));
							pConfig.internal:= 0;
						END_FOR
					END_IF
					IF(pDAV.maxLinesMapping > 0)THEN
						FOR itemIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
							pMapping ACCESS pDAV.pMapping + (itemIdx * SIZEOF(pMapping));
							pMapping.internal:= 0;
						END_FOR
					END_IF
					itemIdx:= 0;																			(* Reset looping index *)
					state:= 2;																				(* Start function block - READ all WRITE data *)
					
				(* Connection closed *)
				ELSIF(pDAV.internal = 1)THEN
					status:= DAV_ERR_CONNECT_CLOSED;

				(* Critical error *)
				ELSE
					status:= DAV_ERR_INITIALIZATION;
				END_IF

			(* Critical error *)
			ELSE
				status:= DAV_ERR_INITIALIZATION;
			END_IF
		END_IF		
		(****************************************************************************************************************************)


		(****************************************************************************************************************************)
		(* Request to initialize the client																																													*)
		(* Note: code placed underneath STATE 0, to ensure pDAV is a valid pointer																									*)
		(****************************************************************************************************************************)
		IF((pDAV.internal = 2) OR (
			(pDAV.connection.protocol <> DAV_PROTOCOL_TCP) AND (pDAV.connection.protocol <> DAV_PROTOCOL_MPI)) )THEN
			errorPackets:= 0;																			(* Clear number of error packets *)
			state:= 0;																						(* Reset function block *)
		END_IF
		(****************************************************************************************************************************)


		(****************************************************************************************************************************)
		(* Pause and Resume the function block                                                   																		*)
		(****************************************************************************************************************************)
		IF((pause = TRUE) AND (state = 1))THEN
			state:= 254;																					(* Pause function block *)
		END_IF
		IF((pause = FALSE) AND (state = 254))THEN
			state:= 1;																						(* Resume function block *)
		END_IF
		paused:= (state = 254);																	(* Show PAUSE status *)
		(****************************************************************************************************************************)


		(****************************************************************************************************************************)
		(* Completed reading all WRITE variables                                                																		*)
		(****************************************************************************************************************************)
		IF((state = 2) AND (itemIdx >= pDAV.maxLinesMapping))THEN

 			(* Clear the internal variables *)
			IF(pDAV.maxLinesConfig > 0)THEN
				FOR itemIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
					pConfig ACCESS pDAV.pConfig + (itemIdx * SIZEOF(pConfig));
					pConfig.internal:= 0;
				END_FOR
			END_IF

			(* Clear the internal variables *)
			IF(pDAV.maxLinesMapping > 0)THEN
				FOR itemIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
					pMapping ACCESS pDAV.pMapping + (itemIdx * SIZEOF(pMapping));
					pMapping.internal:= 0;
				END_FOR
			END_IF

			itemIdx:= 0;																					(* Reset looping index *)
			currentPriority:= 1;																	(* Reset the prioirty *)
			currentMode:= 0;																			(* Set mode to WRITE *)
			state:= 1;																						(* Run main routine *)
		END_IF
		(****************************************************************************************************************************)


		(****************************************************************************************************************************)
		(* Build up packet		                                                                  																		*)
		(****************************************************************************************************************************)
		IF(state = 1)THEN
			memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);				(* Clear write buffer *)
			memset(ADR(varList), 0, SIZEOF(varList));							(* Clear list of variable index's *)
			numItems:= 0;																					(* Clear storage of our number of items *)
			numItemsCfg:= 0;																			(* Clear storage of our number of items *)
			numItemsMap:= 0;																			(* Clear storage of our number of items *)
			DAVexchange_0.sendLength:= 0;													(* Reset length to send *)

			(* Guesstimate the response length *)
			IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
				responseSize:= 21;																	(* Assume message type 3, with 2 byte parameter area *)
			ELSE
				responseSize:= 35;																	(* As above, but with BCC and assume some DLE doubling *)
			END_IF


			(* Repeat until we have data to send *)
			WHILE(state = 1)DO

				(************************************************************************************************************************)
				(* Initialize data																																																			*)
				(************************************************************************************************************************)
			
				(* WRITE mapping limit exceeded *)
				IF((currentMode = 0) AND (itemIdx >= pDAV.maxLinesMapping))THEN
					IF(pDAV.maxLinesConfig > 0)THEN		
						currentMode:= 1;																(* Set mode to READ CONFIG *)
					ELSE
						currentMode:= 2;																(* Set mode to READ MAPPING*)
					END_IF
					itemIdx:= 0;																			(* Reset starting index *)
				
				(* READ config limit exceeded *)
				ELSIF((currentMode = 1) AND (itemIdx >= pDAV.maxLinesConfig))THEN
					currentMode:= 2;																	(* Set mode to READ MAPPING *)
					itemIdx:= 0;																			(* Reset starting index *)

				(* READ mapping limit exceeded *)
				ELSIF((currentMode = 2) AND (itemIdx >= pDAV.maxLinesMapping))THEN
		
		 			(* Clear the internal variables *)
					IF(pDAV.maxLinesConfig > 0)THEN
						FOR itemIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (itemIdx * SIZEOF(pConfig));
							pConfig.internal:= 0;
						END_FOR
					END_IF
					
					(* Clear the internal variables *)
					IF(pDAV.maxLinesMapping > 0)THEN
						FOR itemIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
							pMapping ACCESS pDAV.pMapping + (itemIdx * SIZEOF(pMapping));
							pMapping.internal:= 0;
						END_FOR
					END_IF

	 				currentPriority:= (currentPriority MOD pDAV.maxPrioirty) + 1;		(* Increase the prioirty, reset to 1 *)
					currentMode:= 0;																	(* Set mode to WRITE *)
					itemIdx:= 0;																			(* Reset starting index *)				
				END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Perform a write request 																																															*)
				(************************************************************************************************************************)
				IF(currentMode = 0)THEN
					memset(ADR(writeValues), 0, SIZEOF(writeValues));								(* Clear temp write values *)
					
					(* Determine the maximum size we can send *)
					IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
						maxSendSize:= DAV_PDU_SIZE - 20;								(* 12 byte parameter area, 8 byte data area with 4 byte variable *)
					ELSE
						maxSendSize:= DAV_PDU_SIZE - 30;								(* As above, but assume some DLE doubling *)
					END_IF

					(* Find WRITE requests *)
					FOR addIdx:= itemIdx TO pDAV.maxLinesMapping-1 BY 1 DO
					
						(* Access the current line (high prioirty or current priority) *)
						pMapping ACCESS pDAV.pMapping + (addIdx * SIZEOF(pMapping));

						(* Determine internal flags: *)
						(* "moreLinesToScan" - if we are still in the required priority *)
						(* "bufferFull" - if we have (or about to) reach the maximum limits imposed by the protocol *)
						moreLinesToScan:=	(pMapping.priority <= currentPriority);
						bufferFull:= (DAVexchange_0.sendLength > maxSendSize - pMapping.brVarLength) OR 
													(responseSize >= DAV_PDU_SIZE - 1) OR (numItems >= 20);

						(* Cannot continue *)
						IF((bufferFull = TRUE) OR (moreLinesToScan = FALSE))THEN
							EXIT;
									
						(* W or R/W variables only *)
						ELSIF((pMapping.access = DAV_CONFIG_RW_W) OR (pMapping.access = DAV_CONFIG_RW_B))THEN
							
							(* Ensure variable is enabled *)
							IF(pMapping.pEnable > 0)THEN
			 					pEnable ACCESS pMapping.pEnable;
								useVariable:= (pEnable = TRUE);
							ELSE
								useVariable:= TRUE;
							END_IF
						
							(* Get the current value *)
							curValue:= 0;
							memcpy(ADR(curValue), pMapping.brVarAdr, pMapping.brVarLength);

							(* Packet should be added *)
							IF((useVariable = TRUE) AND (curValue <> pMapping.brPrevValue))THEN

								(* Initialise WRITE request *)
								IF(DAVexchange_0.sendLength = 0)THEN
					 				DAVexchange_0.sendLength:= DAVpacketWriteInit(pHandle, pDAV.pBufferW);		
								END_IF
								
								(* Add variable to packet *)
								DAVexchange_0.sendLength:= DAVpacketWriteAddVar(pHandle, pDAV.pBufferW, pMapping.brVarAdr, ADR(pMapping.var));		
								pMapping.internal:= 1;											(* Set variable in use *)		
								responseSize:= responseSize + 1;						(* Increase estimate response size (16#FF) *)
								writeValues[numItems]:= curValue;						(* Store the value in our temporary buffer *)
								varList[numItems]:= addIdx;									(* Store variable index *)
								numItems:= numItems + 1;										(* Increase number of items *)
						
							(* Set WRITE variables to complete *)
							ELSIF((useVariable = FALSE) OR (pMapping.access = DAV_CONFIG_RW_W))THEN
								pMapping.internal:= 2;
							END_IF
						END_IF					
					END_FOR
		
					(* No items found or limit reached *)
					IF((DAVexchange_0.sendLength = 0) OR (moreLinesToScan = FALSE) OR (addIdx >= pDAV.maxLinesMapping))THEN
						itemIdx:= pDAV.maxLinesMapping;									(* Force a reset on next loop iteration *)
					
					(* More lines remaining *)
					ELSE
						itemIdx:= addIdx;																(* Store the current index (for start of next scan) *)
					END_IF
		
					(* Now perform a WRITE request *)
					IF(DAVexchange_0.sendLength > 0)THEN
					
						(* Perform DLE doubling, DLE + ETX and BCC *)
						IF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
							DAVexchange_0.sendLength:= DAVmpiSuffixCRC(pDAV.pBufferW, DAVexchange_0.sendLength);
						END_IF
						
						(* Continue *)
						state:= 10;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Perform a read request 																																															*)
				(************************************************************************************************************************)
				ELSIF(currentMode = 1)THEN

					(* Config exists *)
					IF(pDAV.maxLinesConfig > 0)THEN
						
						(* Determine the maximum size we can send *)
						IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
							maxSendSize:= DAV_PDU_SIZE - 12;							(* 12 byte parameter area *)
						ELSE
							maxSendSize:= DAV_PDU_SIZE - 22;							(* As above, but assume some DLE doubling *)
						END_IF
	
						(* Find READ requests *)
						FOR addIdx:= itemIdx TO pDAV.maxLinesConfig-1 BY 1 DO

							(* Access the current line (high prioirty or current priority) *)
							pConfig ACCESS pDAV.pConfig + (addIdx * SIZEOF(pConfig));

							(* Determine internal flags: *)
							(* "moreLinesToScan" - if we are still in the required priority *)
							(* "bufferFull" - if we have (or about to) reach the maximum limits imposed by the protocol *)
							moreLinesToScan:=	(pMapping.priority <= currentPriority);
							bufferFull:= (DAVexchange_0.sendLength > maxSendSize) OR
														(responseSize > DAV_PDU_SIZE - 5 - pConfig.var.length) OR 
														(numItems >= 20); 
							
							(* Ensure variable is enabled *)
							IF(pConfig.pEnable > 0)THEN
			 					pEnable ACCESS pConfig.pEnable;
								useVariable:= (pEnable = TRUE);
							ELSE
								useVariable:= TRUE;
							END_IF

							(* Cannot continue *)
							IF((bufferFull = TRUE) OR (moreLinesToScan = FALSE))THEN
								EXIT;
									
							(* Variable not already used *)
							ELSIF((useVariable = TRUE) AND (pConfig.internal = 0))THEN

								(* Initialise READ request *)
								IF(DAVexchange_0.sendLength = 0)THEN
				 					DAVexchange_0.sendLength:= DAVpacketReadInit(pHandle, pDAV.pBufferW);
								END_IF

								(* Add variable to packet *)
								DAVexchange_0.sendLength:= DAVpacketReadAddVar(pHandle, pDAV.pBufferW, ADR(pConfig.var));
								pConfig.internal:= 1;												(* Set variable in use *)
								responseSize:= responseSize + 5 + pConfig.var.length;						(* Increase estimate response size *)
								varList[numItems]:= addIdx;									(* Store variable index *)
								numItems:= numItems + 1;										(* Increase number of items *)
								numItemsCfg:= numItemsCfg + 1;							(* Increase number of items *)
							END_IF		
						END_FOR

						(* No items found or limit reached *)
						IF((DAVexchange_0.sendLength = 0) OR (moreLinesToScan = FALSE) OR (addIdx >= pDAV.maxLinesConfig))THEN
							itemIdx:= pDAV.maxLinesConfig;								(* Force a reset on next loop iteration *)
		
						(* More lines remaining - buffer full *)
						ELSE
							
							(* Perform DLE doubling, DLE + ETX and BCC *)
							IF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
								DAVexchange_0.sendLength:= DAVmpiSuffixCRC(pDAV.pBufferW, DAVexchange_0.sendLength);
							END_IF
						
							(* Continue *)
							itemIdx:= addIdx;															(* Store the current index (for start of next scan) *)
							state:= 20;																		(* Send request now - no more data can be sent *)
						END_IF

					(* No Config *)
					ELSE
						currentMode:= 2;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Perform a read request 																																															*)
				(************************************************************************************************************************)
				ELSE
	
					(* Determine the maximum size we can send *)
					IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
						maxSendSize:= DAV_PDU_SIZE - 12;								(* 12 byte parameter area *)
					ELSE
						maxSendSize:= DAV_PDU_SIZE - 22;								(* As above, but assume some DLE doubling *)
					END_IF
	
					(* Find READ requests *)
					FOR addIdx:= itemIdx TO pDAV.maxLinesMapping-1 BY 1 DO
					
						(* Access the current line (high prioirty or current priority) *)
						pMapping ACCESS pDAV.pMapping + (addIdx * SIZEOF(pMapping));
	
						(* Determine internal flags: *)
						(* "moreLinesToScan" - if we are still in the required priority *)
						(* "bufferFull" - if we have (or about to) reach the maximum limits imposed by the protocol *)
						moreLinesToScan:=	(pMapping.priority <= currentPriority);
						bufferFull:= (DAVexchange_0.sendLength > maxSendSize) OR 
													(responseSize > DAV_PDU_SIZE - 5 - pMapping.brVarLength) OR 
													(numItems >= 20); 

						(* Cannot continue *)
						IF((bufferFull = TRUE) OR (moreLinesToScan = FALSE))THEN
							EXIT;
									
						(* Variable not already used *)
						ELSIF(pMapping.internal = 0)THEN
							
							(* READ request already contains configuration items *)
							IF((numItemsCfg > 0) AND (pMapping.cfgIndex < 65535) AND (pMapping.cfgIndex < pDAV.maxLinesConfig))THEN
			 					pConfig ACCESS pDAV.pConfig + (pMapping.cfgIndex * SIZEOF(pConfig));
								useVariable:= (pConfig.internal <> 1);						(* Use variable if the config is not currently in use *)								
							ELSE
								useVariable:= TRUE;
							END_IF
							
							(* Ensure variable is enabled *)
							IF(pMapping.pEnable > 0)THEN
			 					pEnable ACCESS pMapping.pEnable;
								useVariable:= useVariable AND (pEnable = TRUE);
								
								(* Set variable used if it is disabled *)
								IF(pEnable = FALSE)THEN
									pMapping.internal:= 2;
								END_IF								
							END_IF
							
							(* Variable can be added *)
							IF(useVariable = TRUE)THEN
	
								(* Initialise READ request *)
								IF(DAVexchange_0.sendLength = 0)THEN
				 					DAVexchange_0.sendLength:= DAVpacketReadInit(pHandle, pDAV.pBufferW);		
								END_IF

								(* Add variable to packet *)
								DAVexchange_0.sendLength:= DAVpacketReadAddVar(pHandle, pDAV.pBufferW, ADR(pMapping.var));
								pMapping.internal:= 1;											(* Set variable in use *)
								responseSize:= responseSize + 5 + pMapping.brVarLength;				(* Increase estimate response size *)
								varList[numItems]:= addIdx;									(* Store variable index *)
								numItems:= numItems + 1;										(* Increase number of items *)
								numItemsMap:= numItemsMap + 1;							(* Increase number of items *)
							END_IF
						END_IF
					END_FOR
			
					(* No items found or limit reached *)
					IF((DAVexchange_0.sendLength = 0) OR (moreLinesToScan = FALSE) OR (addIdx >= pDAV.maxLinesMapping))THEN
						itemIdx:= pDAV.maxLinesMapping;									(* Force a reset on next loop iteration *)
		
					(* More lines remaining - buffer full *)
					ELSE
						itemIdx:= addIdx;																(* Store the current index (for start of next scan) *)
					END_IF
				
					(* Now perform a READ request *)
					IF(DAVexchange_0.sendLength > 0)THEN

						(* Perform DLE doubling, DLE + ETX and BCC *)
						IF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
							DAVexchange_0.sendLength:= DAVmpiSuffixCRC(pDAV.pBufferW, DAVexchange_0.sendLength);
						END_IF

						(* Continue *)
						state:= 20;
					
					(* No data to send, exit loop to avoid a cycle time violation *)
					ELSE
						EXIT;					
					END_IF
				END_IF
				(************************************************************************************************************************)
			END_WHILE
		(****************************************************************************************************************************)
		
			
		(****************************************************************************************************************************)
		(* Build up packet READ WRITE data first                                                																		*)
		(****************************************************************************************************************************)	
		ELSIF(state = 2)THEN
			memset(pDAV.pBufferW, 0, DAV_DEFAULT_BUFFER_W);				(* Clear write buffer *)
			memset(ADR(varList), 0, SIZEOF(varList));							(* Clear list of variable index's *)
			numItems:= 0;																					(* Clear storage of our number of items *)
			numItemsCfg:= 0;																			(* Clear storage of our number of items *)
			numItemsMap:= 0;																			(* Clear storage of our number of items *)
			DAVexchange_0.sendLength:= 0;													(* Reset length to send *)
		
			(* Guesstimate the response length *)
			IF(pDAV.connection.protocol = DAV_PROTOCOL_TCP)THEN
				responseSize:= 21;																	(* Assume message type 3, with 2 byte parameter area *)
				maxSendSize:= DAV_PDU_SIZE - 12;										(* 12 byte parameter area *)
			ELSE
				responseSize:= 35;																	(* As above, but with BCC and assume some DLE doubling *)
				maxSendSize:= DAV_PDU_SIZE - 22;										(* As above, but assume some DLE doubling *)
			END_IF

			(**************************************************************************************************************************)
			(* Perform a read request 																																																*)
			(**************************************************************************************************************************)
			FOR addIdx:= itemIdx TO pDAV.maxLinesMapping-1 BY 1 DO

				(* Access the current line (high prioirty or current priority) *)
				pMapping ACCESS pDAV.pMapping + (addIdx * SIZEOF(pMapping));
	
				(* Determine internal flags: *)
				(* "bufferFull" - if we have (or about to) reach the maximum limits imposed by the protocol *)
				bufferFull:= (DAVexchange_0.sendLength > maxSendSize) OR 
											(responseSize > DAV_PDU_SIZE - 5 - pMapping.brVarLength) OR 
											(numItems >= 20); 

				(* Cannot continue *)
				IF(bufferFull = TRUE)THEN
					EXIT;
									
				(* Variable not already used *)
				ELSIF((pMapping.access <> DAV_CONFIG_RW_R) AND (pMapping.internal = 0))THEN

					(* Initialise READ request *)
					IF(DAVexchange_0.sendLength = 0)THEN
	 					DAVexchange_0.sendLength:= DAVpacketReadInit(pHandle, pDAV.pBufferW);
					END_IF
					
					(* Add variable to packet *)
					DAVexchange_0.sendLength:= DAVpacketReadAddVar(pHandle, pDAV.pBufferW, ADR(pMapping.var));
					pMapping.internal:= 1;													(* Set variable in use *)
					responseSize:= responseSize + 5 + pMapping.brVarLength;				(* Increase estimate response size *)
					varList[numItems]:= addIdx;											(* Store variable index *)
					numItems:= numItems + 1;												(* Increase number of items *)
					numItemsMap:= numItemsMap + 1;									(* Increase number of items *)
				END_IF
			END_FOR
			
			(* No items found or limit reached *)
			IF((DAVexchange_0.sendLength = 0) OR (addIdx >= pDAV.maxLinesMapping))THEN
				itemIdx:= pDAV.maxLinesMapping;										(* Force a reset on next loop iteration *)
		
			(* More lines remaining - buffer full *)
			ELSE
				itemIdx:= addIdx;																	(* Store the current index (for start of next scan) *)
			END_IF
	
			(* Now perform a READ request *)
			IF(DAVexchange_0.sendLength > 0)THEN

				(* Perform DLE doubling, DLE + ETX and BCC *)
				IF(pDAV.connection.protocol = DAV_PROTOCOL_MPI)THEN
					DAVexchange_0.sendLength:= DAVmpiSuffixCRC(pDAV.pBufferW, DAVexchange_0.sendLength);
				END_IF

				(* Continue *)
				state:= 30;
			END_IF
		END_IF
		(****************************************************************************************************************************)



		(****************************************************************************************************************************)
		(* Function Operation (R/W)                                                                																	*)
		(****************************************************************************************************************************)
		CASE state OF

			(**************************************************************************************************************************)
			(* Send a WRITE command																								                  																	*)
			(**************************************************************************************************************************)
			10:
				(* Service function *)
				DAVexchange_0();

				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN

					(* Access buffer *)
					ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx;

					(* Ensure we have received a WRITE packet and the correct number of items *)
					IF((ppBuffer[0] = 16#05) AND (ppBuffer[1] = numItems) AND
						(DAVexchange_0.recvParamLength = 2) AND (DAVexchange_0.recvDataLength = numItems))THEN

						(* Re-access buffer *)
						ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx + DAVexchange_0.recvParamLength;
						
						(* Store the value of each variable if it is successfull *)
						FOR findIdx:=0 TO numItems-1 BY 1 DO
							
							(* Access the current line *)
							pMapping ACCESS pDAV.pMapping + (varList[findIdx] * SIZEOF(pMapping));
							
							(* Found an item in use *)
							IF(pMapping.internal = 1)THEN
			 					
								(* Parameter has been written succesfully, copy data into variable's previous value *)
								IF(ppBuffer[findIdx] = 16#FF)THEN
									pMapping.brPrevValue:= writeValues[findIdx];
								
								(* Invalid reponse *)
								ELSE
									status:= DAV_ERR_FAILED_WRITE;
									errorPackets:= errorPackets + 1;
								END_IF
								pMapping.internal:= 2;										(* Set variable completed *)
							END_IF
						END_FOR

					(* Wrong packet received *)
					ELSE
						status:= DAV_ERR_RECV_WRONGPACKET;
						errorPackets:= errorPackets + 1;
					END_IF

					state:= 1;																			(* Return to the running state *)

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
					state:= 0;
				END_IF
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send a READ command																								                  																	*)
			(**************************************************************************************************************************)
			20:
				(* Service function *)
				DAVexchange_0();

				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
	
					(* Access buffer *)
					ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx;
	
					(* Ensure we have received a READ packet and the correct number of items *)
					IF((ppBuffer[0] = 16#04) AND (ppBuffer[1] = numItems) AND
						(DAVexchange_0.recvParamLength = 2) AND (DAVexchange_0.recvDataLength > 0))THEN

						(* Re-access buffer *)
						ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx + DAVexchange_0.recvParamLength;
						readIdx:= 0;

						(*------------------------------------------------------------------------------------------------------------------*)
						(* Store the value of each variable if it is successfull 																														*)
						(*------------------------------------------------------------------------------------------------------------------*)
						IF(numItemsCfg > 0)THEN
							FOR findIdx:=0 TO numItemsCfg-1 BY 1 DO
								pConfig ACCESS pDAV.pConfig + (varList[findIdx] * SIZEOF(pConfig));
					
								(* Found an item in use *)
								IF(pConfig.internal = 1)THEN
			 					
									(* Parameter has been read succesfully - BOOL *)
									IF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#03))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2]));				(* Get datalength as bytes *)

									(* Parameter has been read succesfully - BYTE *)
									ELSIF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#04))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2])) / 8;		(* Get datalength as bytes *)

									(* Error *)
									ELSE
										dataLength:= 0;
										errorPackets:= errorPackets + 1;
									END_IF

									(* Check length is the same and copy *)
									IF((dataLength > 0) AND (dataLength = pConfig.var.length))THEN
										memcpy(pConfig.brVarAdr, ADR(ppBuffer[readIdx+4]), pConfig.var.length);		(* Copy data into memory block *)
									
										(* Now map this data using the mapping congifuration *
										FOR mapIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
											pMapping ACCESS pDAV.pMapping + (mapIdx * SIZEOF(pMapping));
										
											(* Ensure variable is enabled *
											IF(pMapping.pEnable > 0)THEN
			 									pEnable ACCESS pMapping.pEnable;
												useVariable:= (pEnable = TRUE);
											ELSE
												useVariable:= TRUE;
											END_IF
											
											(* Uses a custom mapping - update it *
											DAVcalcVARadr(ADR(pMapping.var));

											IF((useVariable = TRUE) AND
												(pMapping.access < DAV_CONFIG_RW_W) AND
												(pMapping.var.area = pConfig.var.area) AND 
												(pMapping.var.db = pConfig.var.db) AND
												(pMapping.var.bitAdr >= pConfig.var.bitAdr) AND 
												(pMapping.var.bitAdr + SEL((pMapping.var.type = DAV_VAR_BIT), (pMapping.var.length * 8), 1) <= 
												 	pConfig.var.bitAdr + SEL((pConfig.var.type = DAV_VAR_BIT), (pConfig.var.length * 8), 1)))THEN

												(* R/W variable - check if the value has changed *
												IF(pMapping.access = DAV_CONFIG_RW_B)THEN
													curValue:= 0;
													memcpy(ADR(curValue), pMapping.brVarAdr, pMapping.brVarLength);
												END_IF
											
												(* Packet should be updated *
												IF((pMapping.access = DAV_CONFIG_RW_R) OR 
												((pMapping.access = DAV_CONFIG_RW_B) AND (curValue = pMapping.brPrevValue)))THEN
													(*DAVupdateVAR(ADR(pMapping), pConfig.brVarAdr + pMapping.var.actAdr - pConfig.var.actAdr);*
													DAVupdateVAR(ADR(pMapping), pConfig.brVarAdr + (
													((pMapping.var.bitAdr AND 16#FFF8) - pConfig.var.bitAdr) / 8), FALSE);
													pMapping.internal:= 2;
												END_IF
											END_IF
										END_FOR									
									
									(* Error *)
									ELSE
										status:= DAV_ERR_FAILED_READ;
										errorPackets:= errorPackets + 1;
									END_IF
												
									readIdx:= readIdx + 4 + dataLength + (dataLength MOD 2);		(* Next offset (2 byte allignment) *)
									pConfig.internal:= 3;											(* Set variable completed *)
								END_IF
							END_FOR


							(* Now map this data using the mapping congifuration *)
							FOR mapIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
								pMapping ACCESS pDAV.pMapping + (mapIdx * SIZEOF(pMapping));
								
								(* Uses a configuration *)
								IF(pMapping.cfgIndex <> 65535)THEN
									pConfig ACCESS pDAV.pConfig + (pMapping.cfgIndex * SIZEOF(pConfig));				
								
									(* Ensure variable is enabled *)
									useVariable:= (pConfig.internal = 3);
									IF((useVariable = TRUE) AND (pMapping.pEnable > 0))THEN
 										pEnable ACCESS pMapping.pEnable;
										useVariable:= (pEnable = TRUE);
									END_IF
											
									(* Variable can be updated *)
									IF(useVariable = TRUE)THEN

										(* Uses a custom mapping - update it *)
										DAVcalcVARadr(ADR(pMapping.var));

										IF((pMapping.access < DAV_CONFIG_RW_W) AND
											(pMapping.var.area = pConfig.var.area) AND 
											(pMapping.var.db = pConfig.var.db) AND
											(pMapping.var.bitAdr >= pConfig.var.bitAdr) AND 
											(pMapping.var.bitAdr + SEL((pMapping.var.type = DAV_VAR_BIT), (pMapping.var.length * 8), 1) <= 
											 	pConfig.var.bitAdr + SEL((pConfig.var.type = DAV_VAR_BIT), (pConfig.var.length * 8), 1)))THEN

											(* R/W variable - check if the value has changed *)
											IF(pMapping.access = DAV_CONFIG_RW_B)THEN
												curValue:= 0;
												memcpy(ADR(curValue), pMapping.brVarAdr, pMapping.brVarLength);
											END_IF
											
											(* Packet should be updated *)
											IF((pMapping.access = DAV_CONFIG_RW_R) OR 
											((pMapping.access = DAV_CONFIG_RW_B) AND (curValue = pMapping.brPrevValue)))THEN

												DAVupdateVAR(ADR(pMapping), pConfig.brVarAdr + (
												((pMapping.var.bitAdr AND 16#FFF8) - pConfig.var.bitAdr) / 8), FALSE);
												pMapping.internal:= 2;
											END_IF
										END_IF
									END_IF
								END_IF
							END_FOR
							
							(* Set internal to complete *)
							FOR findIdx:=0 TO numItemsCfg-1 BY 1 DO
								pConfig ACCESS pDAV.pConfig + (findIdx * SIZEOF(pConfig));
					
								IF(pConfig.internal = 3)THEN
					 				pConfig.internal:= 2;
								END_IF
							END_FOR
						END_IF
						(*------------------------------------------------------------------------------------------------------------------*)

						(*------------------------------------------------------------------------------------------------------------------*)
						(* Store the value of each variable if it is successfull 																														*)
						(*------------------------------------------------------------------------------------------------------------------*)
						IF(numItemsMap > 0)THEN
							FOR findIdx:=0 TO numItemsMap-1 BY 1 DO
								pMapping ACCESS pDAV.pMapping + (varList[numItemsCfg + findIdx] * SIZEOF(pMapping));
					
								(* Found an item in use *)
								IF(pMapping.internal = 1)THEN
			 					
									(* Parameter has been read succesfully - BOOL *)
									IF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#03))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2]));				(* Get datalength as bytes *)

									(* Parameter has been read succesfully - BYTE *)
									ELSIF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#04))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2])) / 8;		(* Get datalength as bytes *)

									(* Error *)
									ELSE
										dataLength:= 0;
										errorPackets:= errorPackets + 1;
									END_IF

									(* Check length is the same and copy *)
									IF((dataLength > 0) AND (dataLength = pMapping.var.length))THEN

										(* R/W variable - check if the value has changed *)
										IF(pMapping.access = DAV_CONFIG_RW_B)THEN
											curValue:= 0;
											memcpy(ADR(curValue), pMapping.brVarAdr, pMapping.brVarLength);
										END_IF

										(* Packet should be updated *)
										IF((pMapping.access = DAV_CONFIG_RW_R) OR (curValue = pMapping.brPrevValue))THEN
											DAVupdateVAR(ADR(pMapping), ADR(ppBuffer[readIdx+4]), (ppBuffer[readIdx+1] = 16#03));
										END_IF
																						
									(* Error *)
									ELSE
										status:= DAV_ERR_FAILED_READ;
										errorPackets:= errorPackets + 1;
									END_IF
									pMapping.internal:= 2;
								END_IF
								readIdx:= readIdx + 4 + dataLength + (dataLength MOD 2);		(* Next offset (2 byte allignment) *)
							END_FOR
						END_IF
						(*------------------------------------------------------------------------------------------------------------------*)

					(* Wrong packet received *)
					ELSE
						status:= DAV_ERR_RECV_WRONGPACKET;
						errorPackets:= errorPackets + 1;
					END_IF									
					state:= 1;																			(* Return to the running state *)

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
					state:= 0;
				END_IF								
			(**************************************************************************************************************************)


			(**************************************************************************************************************************)
			(* Send a READ command (for WRITE data)																                  																	*)
			(**************************************************************************************************************************)
			30:
				(* Service function *)
				DAVexchange_0();
				
				(* Data sent and received *)
				IF(DAVexchange_0.status = 0)THEN
	
					(* Access buffer *)
					ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx;
	
					(* Ensure we have received a READ packet and the correct number of items *)
					IF((ppBuffer[0] = 16#04) AND (ppBuffer[1] = numItems) AND
						(DAVexchange_0.recvParamLength = 2) AND (DAVexchange_0.recvDataLength > 0))THEN

						(* Re-access buffer *)
						ppBuffer ACCESS pDAV.pBufferR + DAVexchange_0.recvStartOfDataIdx + DAVexchange_0.recvParamLength;
						readIdx:= 0;

						(*------------------------------------------------------------------------------------------------------------------*)
						(* Store the value of each variable if it is successfull 																														*)
						(*------------------------------------------------------------------------------------------------------------------*)
						IF(numItemsMap > 0)THEN
							FOR findIdx:=0 TO numItemsMap-1 BY 1 DO
								pMapping ACCESS pDAV.pMapping + (varList[numItemsCfg + findIdx] * SIZEOF(pMapping));
					
								(* Found an item in use *)
								IF(pMapping.internal = 1)THEN
			 					
									(* Parameter has been read succesfully - BOOL *)
									IF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#03))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2]));				(* Get datalength as bytes *)

									(* Parameter has been read succesfully - BYTE *)
									ELSIF((ppBuffer[readIdx] = 16#FF) AND (ppBuffer[readIdx+1] = 16#04))THEN
										dataLength:= DAVswapWORD(ADR(ppBuffer[readIdx+2])) / 8;		(* Get datalength as bytes *)

									(* Error *)
									ELSE
										dataLength:= 0;
										errorPackets:= errorPackets + 1;
									END_IF

									(* Check length is the same and copy *)
									IF((dataLength > 0) AND (dataLength = pMapping.var.length))THEN

										(* Update variable *)
										DAVupdateVAR(ADR(pMapping), ADR(ppBuffer[readIdx+4]), (ppBuffer[readIdx+1] = 16#03));
							
									(* Error *)
									ELSE
										status:= DAV_ERR_FAILED_READ;
										errorPackets:= errorPackets + 1;
									END_IF
									pMapping.internal:= 2;
								END_IF
								readIdx:= readIdx + 4 + dataLength + (dataLength MOD 2);		(* Next offset (2 byte allignment) *)
							END_FOR
						END_IF
						(*------------------------------------------------------------------------------------------------------------------*)

					(* Wrong packet received *)
					ELSE
						status:= DAV_ERR_RECV_WRONGPACKET;
						errorPackets:= errorPackets + 1;
					END_IF									
					state:= 2;																			(* Return to the running state *)

				(* Error *)
				ELSIF(DAVexchange_0.status <> 65535)THEN
					status:= DAVexchange_0.status;
				END_IF								
			(**************************************************************************************************************************)

		END_CASE
		(****************************************************************************************************************************)
		(* End of Function Operation                                                             																		*)
		(****************************************************************************************************************************)
	END_IF


	(******************************************************************************************************************************)
	(* Reset to state 0 when in error																																															*)
	(******************************************************************************************************************************)
	IF(status <> 65535)THEN
		state:= 0;
	END_IF		
	(******************************************************************************************************************************)


	(******************************************************************************************************************************)
	(* Update when it is safe to disconnect																																												*)
	(******************************************************************************************************************************)
	safeToDisconnect:= (state = 1);
	(******************************************************************************************************************************)

END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVclient																																																							*)
(********************************************************************************************************************************)
