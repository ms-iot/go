// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//todo(ragav): adapt for arm64
#include "textflag.h"

TEXT ·getprocaddress(SB),NOSPLIT,$0
	B	syscall·getprocaddress(SB)

TEXT ·loadlibrary(SB),NOSPLIT,$0
	B	syscall·loadlibrary(SB)
