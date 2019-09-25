// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "funcdata.h"
#include "textflag.h"
#include "tls_arm64.h"

//todo(ragav): add support for windows
TEXT runtime·load_g(SB),NOSPLIT,$0
	// Todo(ragav): Following breakpoint is for debugging purposes only.
	MOVD	$700, R19
	BRK
	
	MOVB	runtime·iscgo(SB), R0
	CMP	$0, R0
	BEQ	nocgo

#ifdef GOOS_windows
	WORD	$0xaa1203e0		// MOVD	R18, R0
	ADD		$0xe10, R0
#else
	MRS_TPIDR_R0
#endif
#ifdef GOOS_darwin
	// Darwin sometimes returns unaligned pointers
	AND	$0xfffffffffffffff8, R0
#endif
	MOVD	runtime·tls_g(SB), R27
	ADD	R27, R0
	MOVD	0(R0), g

nocgo:
	RET

TEXT runtime·save_g(SB),NOSPLIT,$0
#ifdef GOOS_windows
	WORD	$0xaa1203e0					// MOVD	R18, R0 i.e. R0 has the base of TEB
	ADD		$0xe10, R0					// Offset for TLS slots
	MOVD 	$runtime·tls_g(SB), R29		// pointer to tls_g
	MOVD	(R29), R29					// index value of tls_g (in the TSL slots array)
	LSL 	$2, R29, R8					// offset for tls_g
	MOVD	g, (R8)(R0)					// save g to tls
	MOVD	g, R0						// preserve R0 across call to setg<>
	RET
#else	
	MOVB	runtime·iscgo(SB), R0
	CMP	$0, R0
	BEQ	nocgo
	MRS_TPIDR_R0
#ifdef GOOS_darwin
	// Darwin sometimes returns unaligned pointers
	AND	$0xfffffffffffffff8, R0
#endif
	MOVD	runtime·tls_g(SB), R27
	ADD	R27, R0
	MOVD	g, 0(R0)
nocgo:
	RET
#endif

#ifdef TLSG_IS_VARIABLE
GLOBL runtime·tls_g+0(SB), NOPTR, $8
#else
GLOBL runtime·tls_g+0(SB), TLSBSS, $8
#endif
