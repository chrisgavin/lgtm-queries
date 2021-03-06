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
 * Provides classes for working with call graphs derived from intra-procedural data flow.
 */

import semmle.javascript.Expr
import Analysis
private import InferredTypes

/**
 * Holds if `v` is an abstract value representing a concrete value that,
 * when called, invokes function `f`.
 */
private predicate isCallable(AbstractValue v, Function f) {
  f = v.(AbstractFunction).getFunction() or
  f = v.(AbstractClass).getClass().getConstructor().getBody()
}

/**
 * A function call or `new` expression, with information about its potential callees.
 *
 * Both direct calls and reflective calls using `call` or `apply` are modelled.
 */
class CallSite extends @invokeexpr {
  InvokeExpr invk;

  CallSite() { invk = this }

  /** Gets an abstract value representing possible callees of this call site. */
  cached AbstractValue getACalleeValue() {
    result = invk.getCallee().(AnalyzedFlowNode).getAValue()
  }

  /**
   * Gets the data flow node corresponding to the `i`th argument passed to the callee
   * invoked at this call site.
   *
   * For direct calls, this is the `i`th argument to the call itself: for instance,
   * for a call `f(x, y)`, the 0th argument node is `x` and the first argument node is `y`.
   *
   * For reflective calls using `call`, the 0th argument to the call denotes the
   * receiver, so argument positions are shifted by one: for instance, for a call
   * `f.call(x, y, z)`, the 0th argument node is `y` and the first argument node is `z`,
   * while `x` is not an argument node at all.
   *
   * Note that this predicate is not defined for arguments following a spread
   * argument: for instance, for a call `f(x, ...y, z)`, the 0th argument node is `x`,
   * but the position of `z` cannot be determined, hence there are no first and second
   * argument nodes.
   */
  AnalyzedFlowNode getArgumentNode(int i) {
    result = invk.getArgument(i) and
    not invk.isSpreadArgument([0..i])
  }

  /** Gets a potential callee of this call site. */
  Function getACallee() {
    isCallable(getACalleeValue(), result)
  }

  /**
   * Holds if the approximation of possible callees for this call site is
   * affected by the given analysis incompleteness `cause`.
   */
  predicate isIndefinite(DataFlowIncompleteness cause) {
    getACalleeValue().isIndefinite(cause)
  }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be imprecise.
   *
   * We currently track one specific source of imprecision: call
   * resolution relies on flow through global variables, and the flow
   * analysis finds possible callees that are not functions.
   * This usually means that a global variable is used in multiple
   * independent contexts, so tracking flow through it leads to
   * imprecision.
   */
  predicate isImprecise() {
    isIndefinite("global") and
    exists (DefiniteAbstractValue v | v = getACalleeValue() |
      not isCallable(v, _)
    )
  }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be incomplete.
   */
  predicate isIncomplete() {
    // the flow analysis identifies a source of incompleteness other than
    // global flow (which usually leads to imprecision rather than incompleteness)
    any (DataFlowIncompleteness cause | isIndefinite(cause)) != "global"
  }

  /**
   * Holds if our approximation of possible callees for this call site is
   * likely to be imprecise or incomplete.
   */
  predicate isUncertain() {
    isImprecise() or isIncomplete()
  }

  /**
   * Gets a textual representation of this invocation.
   */
  string toString() {
    result = this.(InvokeExpr).toString()
  }

  Location getLocation() {
    result = this.(InvokeExpr).getLocation()
  }
}

/**
 * A reflective function call using `call` or `apply`.
 */
class ReflectiveCallSite extends CallSite {
  AnalyzedFlowNode callee;
  string callMode;

  ReflectiveCallSite() {
    this.(MethodCallExpr).calls(callee, callMode) and
    (callMode = "call" or callMode = "apply")
  }

  override AbstractValue getACalleeValue() {
    result = callee.getAValue()
  }

  override AnalyzedFlowNode getArgumentNode(int i) {
    callMode = "call" and
    result = super.getArgumentNode(i+1)
  }
}
