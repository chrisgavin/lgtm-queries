// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * @name Virtual call from constructor or destructor
 * @description Virtual functions should not be invoked from a constructor or destructor of the same class. Confusingly, virtual functions are resolved statically (not dynamically) in constructors and destructors for the same class. The call should be made explicitly static by qualifying it using the scope resolution operator.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability
 *       readability
 *       language-features
 */
import default

predicate thisCall(FunctionCall c) {
  c.getQualifier() instanceof ThisExpr or
  ((PointerDereferenceExpr)c.getQualifier()).getChild(0) instanceof ThisExpr
}

predicate virtualThisCall(FunctionCall c, Function overridingFunction) {
  c.isVirtual() and
  thisCall(c) and
  overridingFunction = ((VirtualFunction)c.getTarget()).getAnOverridingFunction()
}

// Catch most cases: go into functions in the same class, but only catch direct references to "this"

predicate nonVirtualMember(MemberFunction mf, Class c) {
  mf = c.getAMemberFunction() and
  not (mf instanceof Constructor) and not (mf instanceof Destructor) and
  not mf.isVirtual()
}

predicate callFromNonVirtual(MemberFunction source, Class c, MemberFunction targ) {
  exists (FunctionCall fc | fc.getEnclosingFunction() = source and fc.getTarget() = targ and thisCall(fc)) and
  targ = c.getAMemberFunction() and
  nonVirtualMember(source, c)
}

pragma[noopt]
predicate indirectlyCallsVirtualFunction(MemberFunction caller, Function target, Class c) {
  exists (FunctionCall fc |
    virtualThisCall(fc,_) and
    fc.getEnclosingFunction() = caller and
    fc.getTarget() = target and
    nonVirtualMember(caller, c)
  ) or
  exists (MemberFunction mid |
    indirectlyCallsVirtualFunction(mid, target, c) and
    callFromNonVirtual(caller, c, mid)
  )
}

from FunctionCall call, string explanation, Function virtFunction, Function overridingFunction
where (call.getEnclosingFunction() instanceof Constructor or call.getEnclosingFunction() instanceof Destructor) and
      (
          (virtualThisCall(call, overridingFunction) and explanation = "Call to virtual function $@ which is overridden in $@. If you intend to statically call this virtual function, it should be qualified with " + virtFunction.getDeclaringType().toString() + "::.")
          and virtFunction = call.getTarget()
          and overridingFunction.getDeclaringType().getABaseClass+() = call.getEnclosingFunction().getDeclaringType()
      or
        exists(VirtualFunction target | thisCall(call) and indirectlyCallsVirtualFunction(call.getTarget(), target, _) |
           explanation = "Call to function " + call.getTarget().getName() + " that calls virtual function $@ (overridden in $@)."
           and virtFunction = target
           and overridingFunction = target.getAnOverridingFunction()
           and overridingFunction.getDeclaringType().getABaseClass+() = call.getEnclosingFunction().getDeclaringType()
        )
      )
select call, explanation,
        virtFunction, virtFunction.getName(),
        overridingFunction, overridingFunction.getDeclaringType().getName()