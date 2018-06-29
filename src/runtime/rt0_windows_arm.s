// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// This is the entry point for the program from the
// kernel for an ordinary -buildmode=exe program.
TEXT _rt0_arm_windows(SB),NOSPLIT|NOFRAME,$0
	B	·rt0_go(SB)

// When building with -buildmode=c-shared, this symbol is called when the shared
// library is loaded.
TEXT _rt0_arm_windows_lib(SB),NOSPLIT|NOFRAME,$0
	B	_rt0_arm_lib(SB)
