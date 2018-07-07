// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

#include "textflag.h"

// func servicemain(argc uint32, argv **uint16)
TEXT ·servicemain(SB),NOSPLIT,$0
	MOVW	R0, ·sArgc(SB)
	MOVW	R1, ·sArgv(SB)

	MOVM.DB.W [R1, R2, R3, R4, R14], (R13)  	// push {R1..R4, lr}
	MOVW    R13, R4
	
	BIC     $0x7, R13	// alignment for ABI

	MOVW	·sName(SB), R0
	MOVW	·ctlHandlerExProc(SB), R1
	MOVW	$0, R2
	MOVW	·cRegisterServiceCtrlHandlerExW(SB), R3
	BL      (R3)
	CMP     $0, R0
	BEQ     exit
	MOVW	R0, ·ssHandle(SB)

	MOVW	·goWaitsH(SB), R0
	MOVW	·cSetEvent(SB), R1
	BL      (R1)

	MOVW	·cWaitsH(SB), R0
	MOVW	$-1, R1
	MOVW	·cWaitForSingleObject(SB), R2
	BL      (R2)

exit:
	MOVW	R4, R13		// free extra stack space
	MOVM.IA.W (R13), [R1, R2, R3, R4, R15]	// pop {R1..R4, pc}
