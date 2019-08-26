// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

#include "textflag.h"

//Todo(ragav): write the following function
// func servicemain(argc uint32, argv **uint16)
TEXT ·servicemain(SB),NOSPLIT|NOFRAME,$0
    RET
