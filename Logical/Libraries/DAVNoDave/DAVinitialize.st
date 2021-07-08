(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVinitialize.st																																															*)
(* Author: 				morrisd																																																				*)
(* Created: 			May 26, 2009																																																	*)
(********************************************************************************************************************************)


(********************************************************************************************************************************)
(* DAVinitialize																																																								*)
(*==============================================================================================================================*)
(* Initializes the configuration object to communicate between the PLC and the Siemen's PLC																			*)
(* Note:																																																												*)
(*			1) This function needs to be called in the INIT program. 																																*)
(*			2) It should be called once and not continously in a loop (as we call it in a loop).																		*)
(* Returns a status																																																							*)
(********************************************************************************************************************************)
FUNCTION_BLOCK DAVinitialize


	(* Function not enabled *)
	IF(enable = FALSE)THEN
		status := 65534;
		
	(* Invalid data object *)
	ELSIF((pDOConfig = 0) AND (numItemsConfig > 0))THEN
 		status:= DAV_ERR_CFG_DONAME;

	(* Invalid data object *)
	ELSIF(pDOMapping = 0)THEN
 		status:= DAV_ERR_CFG_DONAME;
 
 	(* Invalid number of items *)
	ELSIF((numItemsConfig > DAV_CONFIG_MAX_LINES) OR (numItemsMapping > DAV_CONFIG_MAX_LINES))THEN
 		status:= DAV_ERR_CFG_MAXLINES;	 
 
	(* Run the function *)
	ELSE
			(* Error occured *)
			IF status <> 65535 AND status <> ERR_OK AND state < 255 THEN
				state := 255;
			END_IF
		
			(**************************************************************************************************************************)
			(* Function Operation                                                                   																	*)
			(**************************************************************************************************************************)
			CASE state OF
		
				(************************************************************************************************************************)
				(* InitStuff		               																															*)
				(************************************************************************************************************************)
				0:
					(* Reset handle *)
					handle:= 0;
					(* Reset our internal counter *)
					scanCount:= 0; 
					(* Make status busy *)
					status:= 65535;
					state:= 1;
				
				(************************************************************************************************************************)
				(* Get DataObject Information - pDOConfig		               																															*)
				(************************************************************************************************************************)
				1:
					
					(* Config Data Object Enabled *)
					IF(numItemsConfig > 0)THEN
						
						(* Get information *)
						DatObjInfo_Config.enable:=		TRUE;										(* Enable function block *)
						DatObjInfo_Config.pName:=			pDOConfig;							(* Pointer to Data Object name *)
						DatObjInfo_Config();																(* Service the function block *)
						scanCount:= scanCount + 1;
						IF ((DatObjInfo_Config.status <> 65535) OR (scanCount > 10000)) THEN
					
							(* Complete *)
							IF((DatObjInfo_Config.status = 0) AND (DatObjInfo_Config.len > 0))THEN
								scanCount := 0;
								state:= 2;
	
							(* Invalid length *)
							ELSIF(DatObjInfo_Config.status = 0)THEN
								status:= DAV_ERR_CFG_DONODATA;
								
							(* Timeout *)
							ELSIF(DatObjInfo_Config.status = 65535)THEN
								status:= DAV_ERR_CFG_TIMEOUT;
								
							(* Error *)
							ELSE
								status:= DatObjInfo_Config.status;
							END_IF	
							
						END_IF				
					
					(* Config Data Object Disabled *)
					ELSE
						state:= 2;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Get DataObject Information - pDOMapping                 																															*)
				(************************************************************************************************************************)
				2:
					(* Get information *)
					DatObjInfo_Map.enable:=				TRUE;										(* Enable function block *)
					DatObjInfo_Map.pName:=				pDOMapping;							(* Pointer to Data Object name *)
					DatObjInfo_Map();																		(* Service the function block *)
					scanCount:= scanCount + 1;
					IF ((DatObjInfo_Map.status <> 65535) OR (scanCount > 100000)) THEN
									
						(* Complete *)
						IF((DatObjInfo_Map.status = 0) AND (DatObjInfo_Map.len > 0))THEN
							scanCount := 0;
							state:= 5;
	
						(* Invalid length *)
						ELSIF(DatObjInfo_Map.status = 0)THEN
							status:= DAV_ERR_CFG_DONODATA;
	
						(* Timeout *)			
						ELSIF(DatObjInfo_Map.status = 65535)THEN
							status:= DAV_ERR_CFG_TIMEOUT;
	
						(* Error *)
						ELSE			
							status:= DatObjInfo_Map.status;
						END_IF	
						
					END_IF				
				(************************************************************************************************************************)
				
				
				(************************************************************************************************************************)
				(* Free all previous memory                 																															*)
				(************************************************************************************************************************)
				5: // If no MemHandle passed -> not using live allocation
					IF pMemIdent <> 0 THEN
						state := 10;
						FOR i := 0 TO SIZEOF(memHandle)/SIZEOF(memHandle[0]) - 1 DO
							(* Memory was allocated earlier *)
							IF memHandle[i] <> 0 THEN
								memFreeFB[i](enable := TRUE, ident:=pMemIdent, mem:=memHandle[i]);
								status_i := memFreeFB[i].status;
							END_IF
							IF status_i <> 0 THEN
								state := 255;
								status := memFreeFB[i].status;
								EXIT;
							END_IF
						END_FOR
						state := 10;
					ELSE
						state := 10;
					END_IF


				(************************************************************************************************************************)
				(* Allocate memory for DAVNoDave library				                   																											*)
				(************************************************************************************************************************)
				10:
					(* Determine length and allocate *)
					lengthToAllocate:=							SIZEOF(pDAV) + 														(* DAV strucutre.. *)
		 																			(numItemsConfig * SIZEOF(pConfig)) +			(* Commms configuration.. *)
										 											(numItemsMapping * SIZEOF(pMapping)) +		(* Mapping configuration.. *)
																					DAV_DEFAULT_BUFFER_R +										(* Read buffer.. *)
																					DAV_DEFAULT_BUFFER_W; 										(* Write buffer *)
					
					IF pMemIdent = 0 THEN (* old style *)
						status_i:= TMP_alloc(lengthToAllocate, ADR(handle));
						
					ELSE (* new flexible style *)
						memAllocFB[0](enable:=TRUE,	ident:=pMemIdent, len:=lengthToAllocate);
						status_i:=memAllocFB[0].status;
						IF status_i = 0 THEN
							memHandle[0] := memAllocFB[0].mem;
							handle := memAllocFB[0].mem;
						END_IF
					END_IF
					//memAllocFB[0](enable:=FALSE);

					(* Complete *)
					IF(status_i = 0)THEN
						
						(* Clear data, if old style is used *)
						IF pMemIdent = 0 THEN
							memset(handle, 0, lengthToAllocate);
						END_IF
											
						(* Access pDAV and store the addresses *)
						pDAV ACCESS handle;
						pDAV.pConfig:= handle + SIZEOF(pDAV);
						pDAV.pMapping:= pDAV.pConfig + (numItemsConfig * SIZEOF(pConfig));
						pDAV.pBufferR:= pDAV.pMapping + (numItemsMapping * SIZEOF(pMapping));
						pDAV.pBufferW:= pDAV.pBufferR + DAV_DEFAULT_BUFFER_R;
						pDAV.maxLinesConfig:= 0;
						pDAV.maxLinesMapping:= 0;
						pDAV.ident:= 0;
						pDAV.internal:= 0;
						memset(ADR(pDAV.connection), 0, SIZEOF(pDAV.connection)); (* ? *)

						(* Access pConfig and pMapping *)
						pConfig ACCESS pDAV.pConfig;
						pMapping ACCESS pDAV.pMapping;
				
						state:= 11;

					(* Error *)
					ELSE
						status:= status_i;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Allocate memory for reading the Data Objects            																															*)
				(************************************************************************************************************************)
				11:
					(* Determine length and allocate *)
					lengthToAllocate:=	MAX(DatObjInfo_Config.len, DatObjInfo_Map.len);		(* Length to create *)
					
					IF pMemIdent = 0 THEN (* old style *)
						status_i:= TMP_alloc(lengthToAllocate, ADR(pDOData));
					ELSE (* new flexible style *)
						memAllocFB[1](enable:=TRUE,	ident:=pMemIdent, len:=lengthToAllocate);
						status_i:=memAllocFB[1].status;
						IF status_i = 0 THEN
							memHandle[1] := memAllocFB[1].mem;
							pDOData := memAllocFB[1].mem;
						END_IF
					END_IF
					//memAllocFB[1](enable:=FALSE);
					
					(* Complete *)
					IF(status_i = 0)THEN
						(* Clear data *)
						memset(pDOData, 0, lengthToAllocate);
						IF(numItemsConfig > 0)THEN
							state:= 20;								(* Read configuration *)
						ELSE
							state:= 30;								(* Read mapping *)
						END_IF
						
					(* Error *)
					ELSE
						status:= status_i;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Read configuration from the specified DataObject        																															*)
				(************************************************************************************************************************)
				20:
					(* Read user's configuration *)
					DatObjRead_0.enable:= TRUE;										(* Enable the function block *)
					DatObjRead_0.ident:= DatObjInfo_Config.ident;					(* Use the DataObj's identity *)
					DatObjRead_0.Offset:= 0;										(* Start from the beginning *)
					DatObjRead_0.pDestination:= pDOData;							(* Read data into DRAM *)
					DatObjRead_0.len:= DatObjInfo_Config.len;						(* Read the entire size of the DO *)
					DatObjRead_0();
					scanCount:= scanCount + 1;
					IF (DatObjRead_0.status <> 65535) OR (scanCount > 100000) THEN
						(* Complete *)
						IF(DatObjRead_0.status = 0)THEN
							scanCount := 0;
							(* Reset offsets *)
							charIdx:= 0;
							configIdx:= 0;
							state:= 21;
	
						(* Timeout *)			
						ELSIF(DatObjRead_0.status = 65535)THEN
							status:= DAV_ERR_CFG_TIMEOUT;
	
						(* Error *)
						ELSE			
							status:= DatObjRead_0.status;
						END_IF
					END_IF									
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Create our configuration								                 																															*)
				(************************************************************************************************************************)
				21:

					(* Access next 500 characters *)
					pData ACCESS (pDOData + charIdx);

					(* Access configuration *)
					pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));

					(* Internal *)
					pConfig.brVarAdr:= 0;
					pConfig.internal:= 0;
					pConfig.pEnable:= 0;
					pConfig.var.pdb:= 0;
					pConfig.var.pStartAdr:= 0;
					pConfig.var.pStartAdrB:= 0;
					pConfig.var.bitAdrB:= 0;

					(* Split data *)
					(* Note: the data should be in the following format *)
					(*	[0]		-		Priority (1-5)														*)
					(*	[1]		-		Enable flag (0 for always enabled)				*)
					(*	[2]		-		Area (M, D, I, O)													*)
					(*	[3]		-		DataBlock Number (0-65535)								*)
					(*	[4]		-		Start Address (numeric)										*)
					(*	[5]		-		Length 																		*)
					(*	[6]		-		NULL																			*)
					posNextNull:= DAVsplit(ADR(pData), ADR(straSplit));

					(* Ensure we have a valid NULL *)
					IF((posNextNull > 0) AND 
						(strlen(ADR(straSplit[0])) > 0) AND
						(strlen(ADR(straSplit[1])) > 0) AND
						(strlen(ADR(straSplit[2])) > 0) AND
						(strlen(ADR(straSplit[3])) > 0) AND
						(strlen(ADR(straSplit[4])) > 0) AND
						(strlen(ADR(straSplit[5])) > 0))THEN
						
						(* Priority *)
						tmpVal:= atoi(ADR(straSplit[0]));
						IF((tmpVal >= 1) AND (tmpVal <= USINT_TO_DINT(DAV_CONFIG_PRIOIRTY_MAX)))THEN
							pConfig.priority:= DINT_TO_USINT(tmpVal);
							pDAV.maxPrioirty:= MAX(pDAV.maxPrioirty, pConfig.priority);
						ELSE
							status:= 101;
						END_IF
					
						(* Enable flag (either 0 or variable) *)
						IF(strcmp(ADR(straSplit[1]), ADR('0')) <> 0)THEN
							tmpAdr:= 0;
							curDataLength:= 0;
							status_i:= PV_xgetadr(ADR(straSplit[1]), ADR(tmpAdr), ADR(curDataLength));
							IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 1))THEN
								pConfig.pEnable:= tmpAdr;
							ELSE
								status:= 102;
							END_IF
						END_IF

						(* Area *)
						IF(strcmp(ADR(straSplit[2]), ADR('D')) = 0)THEN
							pConfig.var.area:= DAV_AREA_DB;
						ELSIF(strcmp(ADR(straSplit[2]), ADR('M')) = 0)THEN
							pConfig.var.area:= DAV_AREA_FLAG;
						ELSIF(strcmp(ADR(straSplit[2]), ADR('I')) = 0)THEN
							pConfig.var.area:= DAV_AREA_INPUT;
						ELSIF(strcmp(ADR(straSplit[2]), ADR('O')) = 0)THEN
							pConfig.var.area:= DAV_AREA_OUTPUT;
						ELSE
							status:= 103;
						END_IF

						(* DataBlock number *)
						IF(pConfig.var.area <> DAV_AREA_DB)THEN
							pConfig.var.db:= 0;
						ELSE
							IF(DAVisnumeric(ADR(straSplit[3])) = TRUE)THEN
								tmpVal:= atoi(ADR(straSplit[3]));
							
								IF((tmpVal >= 0) AND (tmpVal <= 65535))THEN
									pConfig.var.db:= DINT_TO_UINT(tmpVal);
								ELSE
									status:= 104;
								END_IF
							ELSE
								tmpAdr:= 0;
								curDataLength:= 0;
								status_i:= PV_xgetadr(ADR(straSplit[3]), ADR(tmpAdr), ADR(curDataLength));
								IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 2))THEN
									pConfig.var.pdb:= tmpAdr;
								ELSE
									status:= 105;
								END_IF
							END_IF
						END_IF
		
						(* Start address (either value or variable) *)
						IF(DAVisnumeric(ADR(straSplit[4])) = TRUE)THEN
			 				pConfig.var.actAdr:= DINT_TO_UINT(atoi(ADR(straSplit[4])));
						ELSE
							pConfig.var.actAdr:= 0;
							tmpAdr:= 0;
							curDataLength:= 0;
							status_i:= PV_xgetadr(ADR(straSplit[4]), ADR(tmpAdr), ADR(curDataLength));
							IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 2))THEN
								pConfig.var.pStartAdr:= tmpAdr;
							ELSE
								status:= 106;
							END_IF
						END_IF
						
						(* Determine address in bits *)
						(* Note: if (pStartAdrXX > 0) then we need to keep recalculating this *)
						DAVcalcVARadr(ADR(pConfig.var));

						(* Length *)
						tmpVal:= atoi(ADR(straSplit[5]));
						IF((tmpVal > 0) AND (tmpVal < 240))THEN
			 				pConfig.var.length:= DINT_TO_USINT(tmpVal);
						ELSE
							status:= 107;
						END_IF

						pConfig.var.type:= DAV_VAR_BYTE;													(* Variable type *)
						configIdx:= configIdx + 1;															(* Use next configuration *)
						charIdx:= charIdx + posNextNull + 1;												(* Point to next line (nullIdx + 1) *)

						(* Reached number of configurations, or length of DataObject *)
						(* Note: Data Object aligns to 4 bytes *)
						IF((configIdx >= numItemsConfig) OR (charIdx >= DatObjInfo_Config.len - 4))THEN
							pDAV.maxLinesConfig:= configIdx;
							(* Clear memory *)
							memset(pDOData, 0, lengthToAllocate);									(* Number of lines used *)
							scanCount := 0;
							state:= 30;
						END_IF
					ELSE
						status:= 108;
					END_IF						
			
					(* Error occured *)
					IF(status <> 65535)THEN
						state:= 255;
					END_IF
				(************************************************************************************************************************


				(************************************************************************************************************************)
				(* Read mapping from the specified DataObject        																																		*)
				(************************************************************************************************************************)
				30:					
					(* Read user's configuration *)
					DatObjRead_0.enable:= TRUE;					(* Enable the function block *)
					DatObjRead_0.ident:= DatObjInfo_Map.ident;	(* Use the DataObj's identity *)
					DatObjRead_0.Offset:= 0;					(* Start from the beginning *)
					DatObjRead_0.pDestination:= pDOData;		(* Read data into DRAM *)
					DatObjRead_0.len:= DatObjInfo_Map.len;		(* Read the entire size of the DO *)
					DatObjRead_0();																								(* Service the function block *)
					scanCount:= scanCount + 1;
					
					IF (DatObjRead_0.status <> 65535) OR (scanCount > 100000) THEN
						(* Complete *)
						IF(DatObjRead_0.status = 0)THEN
							
							(* Reset offsets *)
							charIdx:= 0;
							configIdx:= 0;
							state:= 31;
	
						(* Timeout *)			
						ELSIF(DatObjRead_0.status = 65535)THEN
							status:= DAV_ERR_CFG_TIMEOUT;
										
						(* Error *)
						ELSE			
							status:= DatObjRead_0.status;
						END_IF
					END_IF				
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Create our mapping											                 																															*)
				(************************************************************************************************************************)
				31:
	
					(* Access next 500 characters *)
					pData ACCESS (pDOData + charIdx);

					(* Access configuration *)
					pMapping ACCESS pDAV.pMapping + (configIdx * SIZEOF(pMapping));

					(* Internal *)
					pMapping.internal:= 0;
					pMapping.cfgIndex:= 65535;
					pMapping.pEnable:= 0;
					pMapping.var.pdb:= 0;
					pMapping.var.pStartAdr:= 0;
					pMapping.var.pStartAdrB:= 0;

					(* Split data *)
					(* Note: the data should be in the following format *)
					(*	[0]		-		Priority (1-5)														*)
					(*	[1]		-		Enable flag (0 for always enabled)				*)
					(*	[2]		-		R/W Access (W, R, B)											*)
					(*	[3]		-		Area (M, D, I, O)													*)
					(*	[4]		-		DataBlock Number (0-65535)								*)
					(*	[5]		-		Start Address (numeric or variable				*)
					(*	[6]		-		Start Address bit (numeric or variable)		*)
					(*	[7]		-		Length 																		*)
					(*	[8]		-		B&R variable name													*)
					(*	[9]		-		NULL																			*)
					posNextNull:= DAVsplit(ADR(pData), ADR(straSplit));

					(* Ensure we have a valid NULL *)
					IF((posNextNull > 0) AND
						(strlen(ADR(straSplit[0])) > 0) AND
						(strlen(ADR(straSplit[1])) > 0) AND
						(strlen(ADR(straSplit[2])) > 0) AND
						(strlen(ADR(straSplit[3])) > 0) AND
						(strlen(ADR(straSplit[4])) > 0) AND
						(strlen(ADR(straSplit[5])) > 0) AND
						(strlen(ADR(straSplit[6])) > 0) AND
						(strlen(ADR(straSplit[7])) > 0) AND
						(strlen(ADR(straSplit[8])) > 0))THEN

						(* Priority *)
						tmpVal:= atoi(ADR(straSplit[0]));
						IF((tmpVal >= 1) AND (tmpVal <= USINT_TO_DINT(DAV_CONFIG_PRIOIRTY_MAX)))THEN
							pMapping.priority:= DINT_TO_USINT(tmpVal);
							pDAV.maxPrioirty:= MAX(pDAV.maxPrioirty, pMapping.priority);
						ELSE
							status:= 109;
						END_IF
					
						(* Enable flag (either 0 or variable) *)
						pMapping.pEnable:= 0;
						IF(strcmp(ADR(straSplit[1]), ADR('0')) <> 0)THEN
							tmpAdr:= 0;
							curDataLength:= 0;
							status_i:= PV_xgetadr(ADR(straSplit[1]), ADR(tmpAdr), ADR(curDataLength));
							IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 1))THEN
								pMapping.pEnable:= tmpAdr;
							ELSE
								status:= 110;
							END_IF
						END_IF
					
						(* R/W Access *)
						IF(strcmp(ADR(straSplit[2]), ADR('W')) = 0)THEN
							pMapping.access:= DAV_CONFIG_RW_W;
						ELSIF(strcmp(ADR(straSplit[2]), ADR('B')) = 0)THEN
							pMapping.access:= DAV_CONFIG_RW_B;
						ELSIF(strcmp(ADR(straSplit[2]), ADR('R')) = 0)THEN
							pMapping.access:= DAV_CONFIG_RW_R;
						ELSE
							status:= 111;
						END_IF

						(* Area *)
						IF(strcmp(ADR(straSplit[3]), ADR('D')) = 0)THEN
							pMapping.var.area:= DAV_AREA_DB;
						ELSIF(strcmp(ADR(straSplit[3]), ADR('M')) = 0)THEN
							pMapping.var.area:= DAV_AREA_FLAG;
						ELSIF(strcmp(ADR(straSplit[3]), ADR('I')) = 0)THEN
							pMapping.var.area:= DAV_AREA_INPUT;
						ELSIF(strcmp(ADR(straSplit[3]), ADR('O')) = 0)THEN
							pMapping.var.area:= DAV_AREA_OUTPUT;
						ELSE
							status:= 112;
						END_IF
					
						(* DataBlock number *)
						IF(pMapping.var.area <> DAV_AREA_DB)THEN
							pMapping.var.db:= 0;
						ELSE
							IF(DAVisnumeric(ADR(straSplit[4])) = TRUE)THEN
								tmpVal:= atoi(ADR(straSplit[4]));
							
								IF((tmpVal >= 0) AND (tmpVal <= 65535))THEN
									pMapping.var.db:= DINT_TO_UINT(tmpVal);
								ELSE
									status:= 113;
								END_IF
							ELSE
								tmpAdr:= 0;
								curDataLength:= 0;
								status_i:= PV_xgetadr(ADR(straSplit[4]), ADR(tmpAdr), ADR(curDataLength));
								IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 2))THEN
									pMapping.var.pdb:= tmpAdr;
								ELSE
									status:= 114;
								END_IF
							END_IF
						END_IF
					
						(* Start address (either value or variable) *)
						pMapping.var.pStartAdr:= 0;
						IF(DAVisnumeric(ADR(straSplit[5])) = TRUE)THEN
			 				pMapping.var.actAdr:= DINT_TO_UINT(atoi(ADR(straSplit[5])));
						ELSE
							(* User has included '+XX' *)
							posPlus:= INT_TO_UINT(FIND(straSplit[5], '+'));
							IF(posPlus > 0)THEN
								pMapping.var.actAdr:= DINT_TO_UINT(atoi(ADR(straSplit[5]) + posPlus));
								memset(ADR(straSplit[5]) + posPlus - 1, 0, SIZEOF(straSplit[0]) - posPlus + 1);
							ELSE
								pMapping.var.actAdr:= 0;								
							END_IF
							tmpAdr:= 0;
							curDataLength:= 0;
							status_i:= PV_xgetadr(ADR(straSplit[5]), ADR(tmpAdr), ADR(curDataLength));
							IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 2))THEN
								pMapping.var.pStartAdr:= tmpAdr;
								IF(posPlus > 0)THEN
									pMapping.var.pStartAdr:= pMapping.var.pStartAdr;
								END_IF
							ELSE
								status:= 115;
							END_IF
						END_IF
						
						(* Start address bit (either value or variable) *)
						pMapping.var.pStartAdrB:= 0;
						IF(DAVisnumeric(ADR(straSplit[6])) = TRUE)THEN
			 				tmpVal:= atoi(ADR(straSplit[6]));
							IF((tmpVal >= 0) AND (tmpVal <= 7))THEN
								pMapping.var.bitAdrB:= DINT_TO_USINT(tmpVal);
							ELSE
								status:= 116;
							END_IF
						ELSE
							tmpAdr:= 0;
							curDataLength:= 0;
							status_i:= PV_xgetadr(ADR(straSplit[6]), ADR(tmpAdr), ADR(curDataLength));
							IF((status_i = 0) AND (tmpAdr <> 0) AND (curDataLength = 1))THEN
								pMapping.var.pStartAdrB:= tmpAdr;
							ELSE
								status:= 117;
							END_IF
						END_IF
						
						(* Determine address in bits *)
						(* Note: if (pStartAdrXX > 0) then we need to keep recalculating this *)
						DAVcalcVARadr(ADR(pMapping.var));

						(* Length *)
						tmpVal:= atoi(ADR(straSplit[7]));
						IF((tmpVal = 1) OR (tmpVal = 2) OR (tmpVal = 4))THEN
			 				pMapping.var.length:= DINT_TO_USINT(tmpVal);
						ELSE
							status:= 118;
						END_IF
						
						(* B&R Variable *)
						tmpAdr:= 0;
						curDataLength:= 0;
						curDimensions:= 0;
						status_i:= PV_xgetadr(ADR(straSplit[8]), ADR(pMapping.brVarAdr), ADR(curDataLength));
						status_i:= status_i OR PV_ninfo(ADR(straSplit[8]), ADR(curVarType), ADR(curDataLength), ADR(curDimensions));  
						IF((status_i = 0) AND ((curDataLength <= 4)) AND (pMapping.brVarAdr > 0))THEN
							pMapping.brVarType:= UDINT_TO_USINT(curVarType);						(* Store variable type *)
							pMapping.brVarLength:= UDINT_TO_USINT(curDataLength);				(* Store variable length *)
							memcpy(ADR(pMapping.brPrevValue), pMapping.brVarAdr, pMapping.brVarLength);		(* Store the previous value *)
						ELSE
							status:= 119;
						END_IF
						
						(* Variable type *)
						IF(pMapping.brVarType = 1)THEN
							pMapping.var.type:= DAV_VAR_BIT;
			 			ELSE
							pMapping.var.type:= DAV_VAR_BYTE;
						END_IF

						configIdx:= configIdx + 1;																	(* Use next configuration *)
						charIdx:= charIdx + posNextNull + 1;												(* Point to next line (nullIdx + 1) *)

						(* Reached number of configurations, or length of DataObject *)
						(* Note: Data Object aligns to 4 bytes *)
						IF((configIdx >= numItemsMapping) OR (charIdx >= DatObjInfo_Map.len - 4))THEN
							pDAV.maxLinesMapping:= configIdx;													(* Number of lines used *)
							state:= 40;
						END_IF
					ELSE
						status:= 120;
					END_IF						
			
					(* Error occured *)
					IF(status <> 65535)THEN
						state:= 255;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Free memory														                 																															*)
				(************************************************************************************************************************)
				40:
					IF pMemIdent = 0 THEN
						(* Free DRAM Memory *)
						status_i:= TMP_free(lengthToAllocate, pDOData);
					ELSE
						memFreeFB[1](enable:=1, ident:=pMemIdent, mem:=pDOData);
						status_i := memFreeFB[1].status;
						memHandle[1] := 0;
					END_IF
	
					(* Complete *)
					IF(status_i = 0)THEN
						state:= 50;

					(* Error *)
					ELSE
						status:= status_i;
						state:= 255;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Allocate memory and assign offsets for Configuration Data																														*)
				(************************************************************************************************************************)
				50:
					(* Reset number of bytes to allocate *)
					lengthToAllocate:= 0;
					
					(* For all lines *)
					IF(pDAV.maxLinesConfig > 0)THEN
						FOR configIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							
							(* Increase memory size *)
							lengthToAllocate:= lengthToAllocate + pConfig.var.length;
						END_FOR
					END_IF
					
					IF pMemIdent = 0 THEN
						(* Create memory partition *)
						status_i:= TMP_alloc(lengthToAllocate, ADR(pDOData));
					ELSE
						memAllocFB[1](enable:=TRUE,	ident:=pMemIdent, len:=lengthToAllocate);
						status_i:=memAllocFB[1].status;
						IF status_i = 0 THEN
							memHandle[1] := memAllocFB[1].mem;
							pDOData := memAllocFB[1].mem;
						END_IF
					END_IF
					
					(* Complete *)
					IF(status_i = 0)THEN
						state:= 60;
						
						(* Clear memory *)
						memset(pDOData, 0, lengthToAllocate);
			
						(* For all lines *)
						IF(pDAV.maxLinesConfig > 0)THEN
							FOR configIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							
								(* Store memory address *)
								pConfig.brVarAdr:= pDOData;
								pDOData:= pDOData + pConfig.var.length;
							END_FOR
						END_IF

					(* Error *)
					ELSE
						status:= status_i;
						state:= 255;
					END_IF
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Organize structures		 								                 																															*)
				(************************************************************************************************************************)
				60:
					(* For all config lines *)
					IF(pDAV.maxLinesConfig > 1)THEN
					
						(* Organize via Priority *)
						FOR configIdx:=0 TO pDAV.maxLinesConfig-2 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfigSwap ACCESS pDAV.pConfig + (orderIdx * SIZEOF(pConfig));
														
								(* Swap items *)
								IF(pConfig.priority > pConfigSwap.priority)THEN
				 					memcpy(ADR(configTemp), ADR(pConfig), SIZEOF(pConfig));
									memcpy(ADR(pConfig), ADR(pConfigSwap), SIZEOF(pConfig));
									memcpy(ADR(pConfigSwap), ADR(configTemp), SIZEOF(pConfig));
								END_IF
							END_FOR
						END_FOR

						(* Organize via Area *
						FOR configIdx:=0 TO pDAV.maxLinesConfig-2 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfigSwap ACCESS pDAV.pConfig + (orderIdx * SIZEOF(pConfig));
														
								(* Swap items *
								IF((pConfig.priority = pConfigSwap.priority) AND
									(pConfig.var.area = DAV_AREA_DB) AND (pConfigSwap.var.area <> DAV_AREA_DB))THEN
					 					memcpy(ADR(configTemp), ADR(pConfig), SIZEOF(pConfig));
										memcpy(ADR(pConfig), ADR(pConfigSwap), SIZEOF(pConfig));
										memcpy(ADR(pConfigSwap), ADR(configTemp), SIZEOF(pConfig));
								END_IF
							END_FOR
						END_FOR

						(* Organize via DataBlock *
						FOR configIdx:=0 TO pDAV.maxLinesConfig-2 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfigSwap ACCESS pDAV.pConfig + (orderIdx * SIZEOF(pConfig));
														
								(* Swap items *
								IF((pConfig.priority = pConfigSwap.priority) AND
									(pConfig.var.area = DAV_AREA_DB) AND (pConfigSwap.var.area = DAV_AREA_DB) AND
									(pConfig.var.db > pConfigSwap.var.db))THEN
					 					memcpy(ADR(configTemp), ADR(pConfig), SIZEOF(pConfig));
										memcpy(ADR(pConfig), ADR(pConfigSwap), SIZEOF(pConfig));
										memcpy(ADR(pConfigSwap), ADR(configTemp), SIZEOF(pConfig));
								END_IF
							END_FOR
						END_FOR

						(* Organize via Start Address *
						FOR configIdx:=0 TO pDAV.maxLinesConfig-2 BY 1 DO
							pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfigSwap ACCESS pDAV.pConfig + (orderIdx * SIZEOF(pConfig));
														
								(* Swap items *
								IF((pConfig.priority = pConfigSwap.priority) AND
									(pConfig.var.area = pConfigSwap.var.area) AND
									(pConfig.var.db = pConfigSwap.var.db) AND
									(pConfig.var.bitAdr > pConfigSwap.var.bitAdr))THEN
					 					memcpy(ADR(configTemp), ADR(pConfig), SIZEOF(pConfig));
										memcpy(ADR(pConfig), ADR(pConfigSwap), SIZEOF(pConfig));
										memcpy(ADR(pConfigSwap), ADR(configTemp), SIZEOF(pConfig));
								END_IF
							END_FOR
						END_FOR
						*)
					END_IF


					(* For all mapping lines *)
					IF(pDAV.maxLinesMapping > 1)THEN

						(* Organize via Priority *)
						FOR configIdx:=0 TO pDAV.maxLinesMapping-2 BY 1 DO
							pMapping ACCESS pDAV.pMapping + (configIdx * SIZEOF(pMapping));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesMapping-1 BY 1 DO
								pMappingSwap ACCESS pDAV.pMapping + (orderIdx * SIZEOF(pMapping));
														
								(* Swap items *)
								IF(pMapping.priority > pMappingSwap.priority)THEN
				 					memcpy(ADR(mappingTemp), ADR(pMapping), SIZEOF(pMapping));
									memcpy(ADR(pMapping), ADR(pMappingSwap), SIZEOF(pMapping));
									memcpy(ADR(pMappingSwap), ADR(mappingTemp), SIZEOF(pMapping));
								END_IF
							END_FOR
						END_FOR
						
						(* Organize via Access *)
						FOR configIdx:=0 TO pDAV.maxLinesMapping-2 BY 1 DO
							pMapping ACCESS pDAV.pMapping + (configIdx * SIZEOF(pMapping));
							FOR orderIdx:=configIdx+1 TO pDAV.maxLinesMapping-1 BY 1 DO
								pMappingSwap ACCESS pDAV.pMapping + (orderIdx * SIZEOF(pMapping));
														
								(* Swap items *)
								IF((pMapping.priority = pMappingSwap.priority) AND
									(pMapping.access < pMappingSwap.access))THEN
				 					memcpy(ADR(mappingTemp), ADR(pMapping), SIZEOF(pMapping));
									memcpy(ADR(pMapping), ADR(pMappingSwap), SIZEOF(pMapping));
									memcpy(ADR(pMappingSwap), ADR(mappingTemp), SIZEOF(pMapping));
								END_IF
							END_FOR
						END_FOR
					END_IF

					(* Complete *)
					state:= 61;
				(************************************************************************************************************************)


				(************************************************************************************************************************)
				(* Store Configuration Index							                 																															*)
				(* Used so we don't replicate the same READ data when sending packets																										*)
				(************************************************************************************************************************)
				61:
					(* For all mapping lines *)
					IF((pDAV.maxLinesMapping > 0) AND (pDAV.maxLinesConfig > 0))THEN
						FOR mappingIdx:=0 TO pDAV.maxLinesMapping-1 BY 1 DO
							pMapping ACCESS pDAV.pMapping + (mappingIdx * SIZEOF(pMapping));
							FOR configIdx:=0 TO pDAV.maxLinesConfig-1 BY 1 DO
								pConfig ACCESS pDAV.pConfig + (configIdx * SIZEOF(pConfig));

								(* Store configuration index if mapping variable fits *)
									IF((pMapping.var.area = pConfig.var.area) AND
										(pMapping.var.db = pConfig.var.db) AND
										(pMapping.var.pdb = pConfig.var.pdb) AND 
										(pMapping.var.pStartAdr = pConfig.var.pStartAdr) AND
										(pMapping.var.bitAdr >= pConfig.var.bitAdr) AND
										(pMapping.var.bitAdr + SEL((pMapping.var.type = DAV_VAR_BIT), (pMapping.var.length * 8), 1) <= 
											pConfig.var.bitAdr + SEL((pConfig.var.type = DAV_VAR_BIT), (pConfig.var.length * 8), 1)))THEN
									pMapping.cfgIndex:= configIdx;
								END_IF
							END_FOR
						END_FOR
					END_IF

					(* Complete *)
					state:= 200;
					status:= 0;
					pDAV.internal:= 1;
				(************************************************************************************************************************)

		
				(************************************************************************************************************************)
				(* Complete										  					                 																															*)
				(************************************************************************************************************************)
				200:
					IF reset THEN
						status := 65535;
						state := 0;
					END_IF
					
				(************************************************************************************************************************)
	
	
				(************************************************************************************************************************)
				(* Error										  					                 																																*)
				(************************************************************************************************************************)
				255:
					IF reset THEN
						status := 65535;
						state := 0;
					END_IF
				(************************************************************************************************************************)

			END_CASE
			(**************************************************************************************************************************)
			(* End of Function Operation                                                            																	*)
			(**************************************************************************************************************************)

			
			(**************************************************************************************************************************)
			(* Check scan count 																																																			*)
			(**************************************************************************************************************************)
			scanCount:= scanCount + 1;																				(* Increase scan count *)
			IF((status = 65535) AND (scanCount > 100000))THEN
	 			status:= DAV_ERR_CFG_TIMEOUT;																		(* Exit while if the scanCount is too large *)
	 		END_IF
			(**************************************************************************************************************************)
		
	END_IF
	
END_FUNCTION_BLOCK
(********************************************************************************************************************************)
(* End of DAVinitialize																																																					*)
(********************************************************************************************************************************)
