(********************************************************************************************************************************)
(* COPYRIGHT -- B&R Industrial Automation																																												*)
(********************************************************************************************************************************)
(* Library:				DAVNoDave																																																			*)
(* File: 					DAVinternal.st																																																*)
(* Author: 				morrisd																																																				*)
(* Created: 			June 04, 2009																																																	*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVswapWORD																																																									*)
(*==============================================================================================================================*)
(* Returns a WORD with the BYTE's swapped																																												*)
(********************************************************************************************************************************)
FUNCTION DAVswapWORD

	(* Swap data *)
	DAVswapWORD:= swapUINT(pUINT);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVswapWORD																																																						*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVswapDWORD																																																									*)
(*==============================================================================================================================*)
(* Returns a DWORD with the WORD's and BYTE's swapped																																						*)
(********************************************************************************************************************************)
FUNCTION DAVswapDWORD

	(* Swap data *)
	DAVswapDWORD:= swapUDINT(pUDINT);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVswapDWORD																																																					*)
(********************************************************************************************************************************)





(********************************************************************************************************************************)
(* DAVgetHIBYTE																																																									*)
(*==============================================================================================================================*)
(* Returns the hi-byte from a WORD																																															*)
(********************************************************************************************************************************)
FUNCTION DAVgetHIBYTE

	(* Return the hi-byte *)
	DAVgetHIBYTE:= UINT_TO_USINT(SHR(input AND 16#FF00, 8) AND 16#00FF);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVgetHIBYTE																																																					*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVgetLOBYTE																																																									*)
(*==============================================================================================================================*)
(* Returns the lo-byte from a WORD 																																															*)
(********************************************************************************************************************************)
FUNCTION DAVgetLOBYTE

	(* Return the lo-byte *)
	DAVgetLOBYTE:= UINT_TO_USINT(input AND 16#00FF);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVgetLOBYTE																																																					*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVaddressBITS																																																								*)
(*==============================================================================================================================*)
(* Returns part of a 3-byte address																																															*)
(********************************************************************************************************************************)
FUNCTION DAVaddressBITS

	(* Return the required address byte *)
	DAVaddressBITS:= UDINT_TO_USINT(SHR(startAdr, (byteNum * 8)) AND 16#000000FF);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVaddressBITS																																																				*)
(********************************************************************************************************************************)





(********************************************************************************************************************************)
(* DAVmakeWORD																																																									*)
(*==============================================================================================================================*)
(* Returns a WORD from 2 bytes																																																	*)
(********************************************************************************************************************************)
FUNCTION DAVmakeWORD

	(* Return a WORD *)
	DAVmakeWORD:= (SHL(USINT_TO_UINT(hiByte) AND 16#00FF, 8) AND 16#FF00) OR (USINT_TO_UINT(loByte) AND 16#00FF);
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVmakeWORD																																																						*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVmakeVAR																																																										*)
(*==============================================================================================================================*)
(* Returns 0																																																										*)
(********************************************************************************************************************************)
FUNCTION DAVupdateVAR

	(* Copy variable into temporary value *)
	tempVar:= 0;
	IF(pMapping.var.length > 4)THEN
		memcpy(ADR(tempVar), pBuffer, 4);
	ELSE
		memcpy(ADR(tempVar), pBuffer, pMapping.var.length);			
	END_IF

	(* Convert value to B&R variable *)
	(* BOOL - transport=3 *)
	IF((pMapping.brVarType = 1) AND (transportBOOL = TRUE))THEN
		pDynBool ACCESS pMapping.brVarAdr;
		pDynBool:= (tempVar = 1);

	(* BOOL transport=4 *)
	ELSIF(pMapping.brVarType = 1)THEN
		pDynBool ACCESS pMapping.brVarAdr;
		pDynBool:= BIT_TST(tempVar, pMapping.var.bitAdrB);

	(* BYTE *)
	ELSIF(pMapping.brVarLength = 1)THEN
		pDynByte ACCESS pMapping.brVarAdr;
		pDynByte:= UDINT_TO_USINT(tempVar);

	(* WORD *)
	ELSIF(pMapping.brVarLength = 2)THEN
		pDynWord ACCESS pMapping.brVarAdr;
		pDynWord:= UDINT_TO_UINT(tempVar);
		pDynWord:= DAVswapWORD(ADR(pDynWord));

	(* DWORD *)
	ELSIF(pMapping.brVarLength = 4)THEN
		pDynDWord ACCESS pMapping.brVarAdr;
		pDynDWord:= DAVswapDWORD(ADR(tempVar));
	END_IF

	(* Store the current value for comparisons *)
	memcpy(ADR(pMapping.brPrevValue), pMapping.brVarAdr, pMapping.brVarLength);		

	(* Return 0 *)
	DAVupdateVAR:= 0;
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVupdateVAR																																																					*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVcalcVARadr																																																								*)
(*==============================================================================================================================*)
(* Returns 0																																																										*)
(********************************************************************************************************************************)
FUNCTION DAVcalcVARadr

	(* Update DB *)
	IF(pVar.pdb > 0)THEN
		pUserDB ACCESS pVar.pdb;
		pVar.db:= pUserDB;
	END_IF

	(* Update StartAdrB *)
	IF(pVar.pStartAdrB > 0)THEN
		pUserStartAdrB ACCESS pVar.pStartAdrB;
		IF(pUserStartAdrB < 8)THEN
			pVar.bitAdrB:= pUserStartAdrB;
		ELSE
			pVar.bitAdrB:= 7;
		END_IF
	END_IF
	
	(* Update StartAdr *)
	IF(pVar.pStartAdr > 0)THEN
 		pUserStartAdr ACCESS pVar.pStartAdr;
		pVar.bitAdr:= ((pUserStartAdr + pVar.actAdr) * 8) + pVar.bitAdrB;

	(* Update variable *)
	ELSE
		pVar.bitAdr:= (pVar.actAdr * 8) + pVar.bitAdrB;
	END_IF
	
	(* Return 0 *)
	DAVcalcVARadr:= 0;
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVcalcVARadr																																																					*)
(********************************************************************************************************************************)


(********************************************************************************************************************************)
(* DAVsplit																																																											*)
(*==============================================================================================================================*)
(* Returns position of NULL																																																			*)
(********************************************************************************************************************************)
FUNCTION DAVsplit
	
	(* Default response *)
	DAVsplit:= 0;
	
	(* Valid address *)
	IF(pData > 0)THEN
 		(* Access data *)
		ppData ACCESS pData;
	
		(* Clear string data *)
		memset(ADR(pSplitData), 0, SIZEOF(pSplitData));
		splitIdx:= 0;
		copyIdx:= 0;
		
		(* Check each character *)
		FOR charIdx:=0 TO 499 BY 1 DO
			
			(* Access data *)
			ppSplitData ACCESS ADR(pSplitData[splitIdx]);
			
			(* NULL - all data found *)
			IF(ppData[charIdx] = 0)THEN
	 			DAVsplit:= charIdx;
				EXIT;
			
			(* COMMA (,) (44) - end of current line *)					
			ELSIF(ppData[charIdx] = 44)THEN
	 			splitIdx:= splitIdx + 1;
				copyIdx:= 0;
		
			(* Non-space, copy character *)
			ELSIF(ppData[charIdx] <> 32)THEN
			 ppSplitData[copyIdx]:= ppData[charIdx];
			 copyIdx:= copyIdx + 1;
	 		END_IF
			
			(* Limit exceeded *)
			IF(splitIdx >= 10)THEN
	 			EXIT;
			END_IF							
		END_FOR
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVsplit																																																							*)
(********************************************************************************************************************************)



(********************************************************************************************************************************)
(* DAVisnumeric																																																									*)
(*==============================================================================================================================*)
(* Returns if a string is a numeric																																															*)
(********************************************************************************************************************************)
FUNCTION DAVisnumeric
	
	(* Valid pointer *)
	IF(pString <> 0)THEN
 		pData ACCESS pString;
		
		(* Scan each character *)
		DAVisnumeric:= TRUE;
		FOR charIdx:=0 TO 99 BY 1 DO
			
			(* NULL - no more data *)
			IF(pData[charIdx] = 0)THEN
	 			EXIT;
			
			(* Check character *)
			ELSE
				DAVisnumeric:= DAVisnumeric AND (pData[charIdx] >= 48) AND (pData[charIdx] <= 57);
			END_IF
			
			(* Not a numeric *)
			IF(DAVisnumeric = FALSE)THEN
	 			EXIT;
			END_IF
		END_FOR		

 	(* Invalid pointer *)
 	ELSE
		DAVisnumeric:= FALSE;
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVisnumeric																																																					*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVmpiChecksum																																																								*)
(*==============================================================================================================================*)
(* Returns if the checksum is correct																																														*)
(********************************************************************************************************************************)
FUNCTION DAVmpiCalcCS
	
	(* Valid length *)
	IF((len > 1) AND (len < 100))THEN

		(* Clear checksum *)
		checksum:= 0;
		
		(* Calculate cheskum *)
		FOR charIdx:=0 TO len-2 BY 1 DO
			checksum:= checksum XOR pBuffer[charIdx];
		END_FOR

		(* Return if checksum is correct *)
		DAVmpiCalcCS:= (checksum = pBuffer[len-1]);
 		
	(* Invalid length *)
	ELSE
		DAVmpiCalcCS:= FALSE;
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVmpiChecksum																																																				*)
(********************************************************************************************************************************)


(********************************************************************************************************************************)
(* DAVmpiChecksum																																																								*)
(*==============================================================================================================================*)
(* Returns if the checksum is correct																																														*)
(********************************************************************************************************************************)
FUNCTION DAVmpiSuffixCRC
	
	(* Valid length *)
	IF((len > 1) AND (len < 500))THEN

		(* Clear checksum (with DLE and ETX) *)
		bcc:= 16#10 XOR 16#03;
		destIdx:= 0;

		(* Copy buffer *)
		memset(ADR(bufferR), 0, SIZEOF(bufferR));
		memcpy(ADR(bufferR), ADR(pBuffer), len);

		(* Double any DLE's *)
		(* Calculate cheskum *)
		FOR sourceIdx:=0 TO len-1 BY 1 DO
			
			(* Normal Character *)
			IF(bufferR[sourceIdx] <> 16#10)THEN
				pBuffer[destIdx]:= bufferR[sourceIdx];
				destIdx:= destIdx + 1;
				bcc:= bcc XOR bufferR[sourceIdx];
				
			(* DLE - perform DLE doubling *)
			(* Don;t bother updating checksum - as it remains the same *)
			ELSE
				pBuffer[destIdx]:= 16#10;
				pBuffer[destIdx+1]:= 16#10;
				destIdx:= destIdx + 2;
			END_IF
		END_FOR		
 		
		(* Add DLE and ETX *)
		pBuffer[destIdx]:=		16#10;
		pBuffer[destIdx+1]:=	16#03;
		pBuffer[destIdx+2]:=	bcc;
		
		(* Return the length *)
		DAVmpiSuffixCRC:= destIdx + 3;

	(* Invalid length *)
	ELSE
		DAVmpiSuffixCRC:= 0;
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVmpiChecksum																																																				*)
(********************************************************************************************************************************)




(********************************************************************************************************************************)
(* DAVdecodeMPI																																																									*)
(*==============================================================================================================================*)
(* Removes DLE doubling in the specified buffer																																									*)
(* Returns the length of data in the original buffer																																						*)
(********************************************************************************************************************************)
FUNCTION DAVdecodeMPI

	(* Valid buffer size and length of data in the buffer *)
	IF((dataLength > 0) AND (dataLength <= SIZEOF(bufferOrig)) AND (dataLength < bufferSize) AND (bufferSize > 0))THEN

		(* Copy message into our local buffer, and clear the original message *)
		memset(ADR(bufferOrig), 0, SIZEOF(bufferOrig));
		memcpy(ADR(bufferOrig), ADR(pBuffer), dataLength);
		memset(ADR(pBuffer), 0, bufferSize);

		(* Remove DLE doubling - otherwise the offsets are messed up! *)
		destIdx:= 0;
		FOR sourceIdx:=0 TO dataLength-1 BY 1 DO

			(* Copy character *)
			pBuffer[destIdx]:= bufferOrig[sourceIdx];
			destIdx:= destIdx + 1;
			
			(* DLE doubling *)
			IF((bufferOrig[sourceIdx] = 16#10) AND (bufferOrig[sourceIdx+1] = 16#10))THEN
				sourceIdx:= sourceIdx + 1;
			END_IF
		END_FOR

		(* Return the new length of the buffer *)
		DAVdecodeMPI:= destIdx;
 
 	(* Invalid parameters *)
	ELSE
		DAVdecodeMPI:= 0;
	END_IF
END_FUNCTION
(********************************************************************************************************************************)
(* End of DAVdecodeMPI																																																					*)
(********************************************************************************************************************************)
		