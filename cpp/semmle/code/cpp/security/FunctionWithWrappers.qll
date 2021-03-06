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

import cpp
import PrintfLike
private import TaintTracking

private
string toCause(Function func, int index)
{
  result = func.getQualifiedName() + "(" + func.getParameter(index).getName() + ")"
}

/**
 * Whether the parameter at index 'sourceParamIndex' of function 'source' is passed
 * (without any evident changes) to the parameter at index 'targetParamIndex' of function 'target'.
 */
private
predicate wrapperFunctionStep(Function source, int sourceParamIndex, Function target, int targetParamIndex)
{
  not target.isVirtual() and
  not source.isVirtual() and
  source.isDefined() and

  exists(Call call, Expr arg, Parameter sourceParam |
    // there is a 'call' to 'target' with argument 'arg' at index 'targetParamIndex'
    target = resolveCall(call) and
    arg = call.getArgument(targetParamIndex) and

    // 'call' is enclosed in 'source'
    source = call.getEnclosingFunction() and

    // 'arg' is an access to the parameter at index 'sourceParamIndex' of function 'source'
    sourceParam = source.getParameter(sourceParamIndex) and
    not exists(sourceParam.getAnAssignedValue()) and
    arg = sourceParam.getAnAccess()
  )
}

/**
 * An abstract class for representing functions that may have wrapper functions.
 * Wrapper functions propagate an argument (without any evident changes) to this function
 * through one or more steps in a call chain.
 *
 * The design motivation is to report a violation at the location of the argument
 * in a call to the wrapper function rather than the function being wrapped, since
 * that is usually the more appropriate place to fix the violation.
 *
 * Subclasses should override the characteristic predicate and 'interestingArg'.
 */
abstract class FunctionWithWrappers extends Function {

  /**
   * Which argument indices are relevant for wrapper function detection.
   */
  predicate interestingArg(int arg) {
    none()
  }
    
  /**
   * Whether 'func' is a (possibly nested) wrapper function that feeds a parameter at the given index
   * through to an interesting parameter of 'this' function at the given call chain 'depth'.
   * The call chain depth is limited to 4.
   */
  private
  predicate wrapperFunctionLimitedDepth(Function func, int paramIndex, string callChain, int depth)
  {
    // base case
    (
      func = this and
      interestingArg(paramIndex) and
      callChain = toCause(func, paramIndex) and
      depth = 0
    )
    // recursive step
    or
    exists(Function target, int targetParamIndex, string targetCause, int targetDepth |
      this.wrapperFunctionLimitedDepth(target, targetParamIndex, targetCause, targetDepth)
      and targetDepth < 4
      and wrapperFunctionStep(func, paramIndex, target, targetParamIndex)
      and callChain = toCause(func, paramIndex) + ", which calls " + targetCause
      and depth = targetDepth + 1
    )
  }
  
  /**
   * Whether 'func' is a (possibly nested) wrapper function that feeds a parameter at the given index
   * through to an interesting parameter of 'this' function.
   *
   * The 'cause' gives the name of 'this' interesting function and its relevant parameter
   * at the end of the call chain.
   */
  private
  predicate wrapperFunctionAnyDepth(Function func, int paramIndex, string cause)
  {
    // base case
    (
      func = this and
      interestingArg(paramIndex) and
      cause = toCause(func, paramIndex)
    )
    // recursive step
    or
    exists(Function target, int targetParamIndex |
      this.wrapperFunctionAnyDepth(target, targetParamIndex, cause)
      and wrapperFunctionStep(func, paramIndex, target, targetParamIndex)
    )
  }
  
  /**
   * Whether 'func' is a (possibly nested) wrapper function that feeds a parameter at the given index
   * through to an interesting parameter of 'this' function.
   *
   * If there exists a call chain with depth at most 4, the 'cause' reports the smallest call chain.
   * Otherwise, the 'cause' merely reports the name of 'this' interesting function and its relevant
   * parameter at the end of the call chain.
   *
   * If there is more than one possible 'cause', a unique one is picked (by lexicographic order).
   */
  predicate wrapperFunction(Function func, int paramIndex, string cause)
  {
    (
      cause = min(string callChain, int depth |
        this.wrapperFunctionLimitedDepth(func, paramIndex, callChain, depth) and
        depth = min(int d | this.wrapperFunctionLimitedDepth(func, paramIndex, _, d) | d)
      | callChain
      )
    )
    or
    (
      not this.wrapperFunctionLimitedDepth(func, paramIndex, _, _) and
      cause = min(string targetCause, string possibleCause |
        this.wrapperFunctionAnyDepth(func, paramIndex, targetCause) and
        possibleCause = toCause(func, paramIndex) + ", which ends up calling " + targetCause
      | possibleCause
      )
    )
  }
  
  /**
   * Whether 'arg' is an argument in a call to an outermost wrapper function of 'this' function.
   */
  predicate outermostWrapperFunctionCall(Expr arg, string callChain)
  {
    exists(Function func, Call call, int argIndex |
      func = resolveCall(call)
      and this.wrapperFunction(func, argIndex, callChain)
      and not wrapperFunctionStep(call.getEnclosingFunction(), _, func, argIndex)
      and arg = call.getArgument(argIndex)
    )
  }

}


class PrintfLikeFunction extends FunctionWithWrappers {
  PrintfLikeFunction() {
    printfLikeFunction(this, _)
  }

  predicate interestingArg(int arg) {
    printfLikeFunction(this, arg)
  }
}
