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

import java
import dataflow.DefUse

/**
 * A library method that acts like `String.format` by formatting a number of
 * its arguments according to a format string.
 */
class StringFormatMethod extends Method {
  StringFormatMethod() {
    (
      this.hasName("format") or
      this.hasName("printf") or
      this.hasName("readLine") or
      this.hasName("readPassword")
    ) and (
      this.getDeclaringType().hasQualifiedName("java.lang", "String") or
      this.getDeclaringType().hasQualifiedName("java.io", "PrintStream") or
      this.getDeclaringType().hasQualifiedName("java.io", "PrintWriter") or
      this.getDeclaringType().hasQualifiedName("java.io", "Console") or
      this.getDeclaringType().hasQualifiedName("java.util", "Formatter")
    )
  }

  /** Gets the index of the format string argument. */
  int getFormatStringIndex() {
    result = 0 and this.getSignature() = "format(java.lang.String,java.lang.Object[])" or
    result = 0 and this.getSignature() = "printf(java.lang.String,java.lang.Object[])" or
    result = 1 and this.getSignature() = "format(java.util.Locale,java.lang.String,java.lang.Object[])" or
    result = 1 and this.getSignature() = "printf(java.util.Locale,java.lang.String,java.lang.Object[])" or
    result = 0 and this.getSignature() = "readLine(java.lang.String,java.lang.Object[])" or
    result = 0 and this.getSignature() = "readPassword(java.lang.String,java.lang.Object[])"
  }
}

/**
 * Holds if `c` wraps a call to a `StringFormatMethod`, such that `fmtix` is
 * the index of the format string argument to `c` and the following and final
 * argument is the `Object[]` that holds the arguments to be formatted.
 */
private predicate formatWrapper(Callable c, int fmtix) {
  exists(Parameter fmt, Parameter args, Call fmtcall, int i |
    fmt = c.getParameter(fmtix) and
    fmt.getType() instanceof TypeString and
    args = c.getParameter(fmtix+1) and
    args.getType().(Array).getElementType() instanceof TypeObject and
    c.getNumberOfParameters() = fmtix+2 and
    fmtcall.getEnclosingCallable() = c and
    (formatWrapper(fmtcall.getCallee(), i) or fmtcall.getCallee().(StringFormatMethod).getFormatStringIndex() = i) and
    fmtcall.getArgument(i) = fmt.getAnAccess() and
    fmtcall.getArgument(i+1) = args.getAnAccess()
  )
}

/**
 * A call to a `StringFormatMethod` or a callable wrapping a `StringFormatMethod`.
 */
class FormattingCall extends Call {
  FormattingCall() {
    this.getCallee() instanceof StringFormatMethod or
    formatWrapper(this.getCallee(), _)
  }

  /** Gets the index of the format string argument. */
  private int getFormatStringIndex() {
    this.getCallee().(StringFormatMethod).getFormatStringIndex() = result or
    formatWrapper(this.getCallee(), result)
  }

  /** Gets the argument to this call in the position of the format string */
  Expr getFormatArgument() {
    result = this.getArgument(this.getFormatStringIndex())
  }

  /** Holds if the varargs argument is given as an explicit array. */
  private predicate hasExplicitVarargsArray() {
    this.getNumArgument() = this.getFormatStringIndex() + 2 and
    this.getArgument(1 + this.getFormatStringIndex()).getType() instanceof Array
  }

  /** Gets the length of the varargs array if it can determined. */
  int getVarargsCount() {
    if this.hasExplicitVarargsArray() then
      exists(Expr arg | arg = this.getArgument(1 + this.getFormatStringIndex()) |
        result = arg.(ArrayCreationExpr).getFirstDimensionSize() or
        result = arg.(VarAccess).getVariable().getAnAssignedValue().(ArrayCreationExpr).getFirstDimensionSize()
      )
    else
      result = this.getNumArgument() - this.getFormatStringIndex() - 1
  }

  /** Gets a `FormatString` that is used by this call. */
  FormatString getAFormatString() {
    result.getAFormattingUse() = this
  }
}

/**
 * A call to a `format` or `printf` method.
 */
class StringFormat extends MethodAccess, FormattingCall {
  StringFormat() {
    this.getCallee() instanceof StringFormatMethod
  }
}

/**
 * Holds if `fmt` is used as part of a format string.
 */
private predicate formatStringFragment(Expr fmt) {
  any(FormattingCall call).getFormatArgument() = fmt or
  exists(Expr e | formatStringFragment(e) |
    e.(VarAccess).getVariable().getAnAssignedValue() = fmt or
    e.(AddExpr).getLeftOperand() = fmt or
    e.(AddExpr).getRightOperand() = fmt or
    e.(ConditionalExpr).getTrueExpr() = fmt or
    e.(ConditionalExpr).getFalseExpr() = fmt or
    e.(ParExpr).getExpr() = fmt
  )
}

/**
 * Holds if `e` is a part of a format string with the approximate value
 * `fmtvalue`. The value is approximated by ignoring details that are
 * irrelevant for determining the number of format specifiers in the resulting
 * string.
 */
private predicate formatStringValue(Expr e, string fmtvalue) {
  formatStringFragment(e) and
  (
    e.(StringLiteral).getRepresentedString() = fmtvalue or
    e.getType() instanceof IntegralType and fmtvalue = "1" or // dummy value
    e.getType() instanceof BooleanType and fmtvalue = "x" or // dummy value
    e.getType() instanceof EnumType and fmtvalue = "x" or // dummy value
    formatStringValue(e.(ParExpr).getExpr(), fmtvalue) or
    exists(Variable v |
      e = v.getAnAccess() and
      v.isFinal() and
      v.getType() instanceof TypeString and
      formatStringValue(v.getInitializer(), fmtvalue)
    ) or
    exists(LocalVariableDecl v |
      e = v.getAnAccess() and
      not exists(AssignAddExpr aa | aa.getDest() = v.getAnAccess()) and
      1 = count(v.getAnAssignedValue()) and
      v.getType() instanceof TypeString and
      formatStringValue(v.getAnAssignedValue(), fmtvalue)
    ) or
    exists(AddExpr add, string left, string right |
      add = e and
      add.getType() instanceof TypeString and
      formatStringValue(add.getLeftOperand(), left) and
      formatStringValue(add.getRightOperand(), right) and
      fmtvalue = left + right
    ) or
    formatStringValue(e.(ConditionalExpr).getTrueExpr(), fmtvalue) or
    formatStringValue(e.(ConditionalExpr).getFalseExpr(), fmtvalue) or
    exists(Method getprop, MethodAccess ma, string prop |
      e = ma and
      ma.getMethod() = getprop and
      getprop.hasName("getProperty") and
      getprop.getDeclaringType().hasQualifiedName("java.lang", "System") and
      getprop.getNumberOfParameters() = 1 and
      ma.getAnArgument().(StringLiteral).getRepresentedString() = prop and
      (prop = "line.separator" or prop = "file.separator" or prop = "path.separator") and
      fmtvalue = "x" // dummy value
    ) or
    exists(Field f |
      e = f.getAnAccess() and
      f.getDeclaringType().hasQualifiedName("java.io", "File") and
      fmtvalue = "x" // dummy value
      |
      f.hasName("pathSeparator") or
      f.hasName("pathSeparatorChar") or
      f.hasName("separator") or
      f.hasName("separatorChar")
    )
  )
}

/**
 * A string that is used as the format string in a `FormattingCall`.
 */
class FormatString extends string {
  FormatString() {
    formatStringValue(_, this)
  }

  /** Gets a `FormattingCall` that uses this as its format string. */
  FormattingCall getAFormattingUse() {
    exists(Expr fmt | formatStringValue(fmt, this) |
      result.getFormatArgument() = fmt or
      exists(VariableAssign va |
        defUsePair(va, result.getFormatArgument()) and va.getSource() = fmt
      ) or
      result.getFormatArgument().(FieldAccess).getField().getAnAssignedValue() = fmt
    )
  }

  /**
   * Gets a boolean value that indicates whether the `%` character at index `i`
   * is an escaped percentage sign or a format specifier.
   */
  private boolean isEscapedPct(int i) {
    this.charAt(i) = "%" and
    if this.charAt(i-1) = "%" then
      result = this.isEscapedPct(i-1).booleanNot()
    else
      result = false
  }

  /** Holds if the format specifier at index `i` is a reference to an argument. */
  private predicate fmtSpecIsRef(int i) {
    false = this.isEscapedPct(i) and
    this.charAt(i) = "%" and
    exists(string c |
      c = this.charAt(i+1) and
      c != "%" and
      c != "n"
    )
  }

  /**
   * Holds if the format specifier at index `i` refers to the same argument as
   * the preceding format specifier.
   */
  private predicate fmtSpecRefersToPrevious(int i) {
    this.fmtSpecIsRef(i) and
    "<" = this.charAt(i+1)
  }

  /**
   * Gets the index of the specific argument (1-indexed) that the format
   * specifier at index `i` refers to, if any.
   */
  private int fmtSpecRefersToSpecificIndex(int i) {
    this.fmtSpecIsRef(i) and
    exists(string num |
      result = num.toInt()
      |
      num = this.charAt(i+1) and "$" = this.charAt(i+2) or
      num = this.charAt(i+1) + this.charAt(i+2) and "$" = this.charAt(i+3)
    )
  }

  /**
   * Holds if the format specifier at index `i` refers to the next argument in
   * sequential order.
   */
  private predicate fmtSpecRefersToSequentialIndex(int i) {
    this.fmtSpecIsRef(i) and
    not exists(this.fmtSpecRefersToSpecificIndex(i)) and
    not this.fmtSpecRefersToPrevious(i)
  }

  /**
   * Gets the largest argument index (1-indexed) that is referred by a format
   * specifier. Gets the value 0 if there are no format specifiers.
   */
  int getMaxFmtSpecIndex() {
    result = max(int ix |
      ix = fmtSpecRefersToSpecificIndex(_) or
      ix = count(int i | fmtSpecRefersToSequentialIndex(i))
    )
  }

  /**
   * Gets an argument index (1-indexed) less than `getMaxFmtSpecIndex()` that
   * is not referred by any format specifier.
   */
  int getASkippedFmtSpecIndex() {
    result in [1..getMaxFmtSpecIndex()] and
    result > count(int i | fmtSpecRefersToSequentialIndex(i)) and
    not result = fmtSpecRefersToSpecificIndex(_)
  }
}
