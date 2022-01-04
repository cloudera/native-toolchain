// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
// When rebasing Kudu, builds with Clang started to fail to link
// with the following message:
//   libLLVMCodeGen.a(TargetPassConfig.cpp.o):TargetPassConfig.cpp:function
//   llvm::TargetPassConfig::createRegAllocPass(bool): error: relocation refers
//   to global symbol "std::call_once<void (&)()>(std::once_flag&, void (&)())::{lambda()#2}::_FUN()",
//   which is defined in a discarded section
//   section group signature: "_ZZSt9call_onceIRFvvEJEEvRSt9once_flagOT_DpOT0_ENKUlvE0_clEv"
//   prevailing definition is from ../../build/debug/security/libsecurity.a(openssl_util.cc.o)
//
// The underlying problem is that the symbols is coming from Kudu client,
// but the symbol is discarded. The purpose of this file is to generate
// the same symbol in a shared library so that the symbol can be satisfied.

#include <mutex>
#include "calloncehack.h"

namespace calloncehack {

// This is a meaningless variable to give the call_once() function
// something to do.
bool calloncehack_initialized = false;

// A call_once() invocation of this function will have the appropriate symbol
void DoInitializeCallOnceHack() {
  calloncehack_initialized=true;
}

void InitializeCallOnceHack() {
  static std::once_flag calloncehack_once;
  std::call_once(calloncehack_once, DoInitializeCallOnceHack);
}

}
