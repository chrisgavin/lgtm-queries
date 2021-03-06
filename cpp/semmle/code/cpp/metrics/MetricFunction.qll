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

import semmle.code.cpp.Function
import semmle.code.cpp.stmts.Stmt

/**
 * A wrapper of metrics for C++ classes
 */
class MetricFunction extends Function {

  /** the number of parameters */
  int getNumberOfParameters() {
    result = count(this.getAParameter())
  }

  /** the number of lines in this function */
  int getNumberOfLines() {
    numlines(this,result,_,_)
  }

  /** the number of lines of code in this function */
  int getNumberOfLinesOfCode() {
    numlines(this,_,result,_)
  }

  /** the number of lines of comments in this function */
  int getNumberOfLinesOfComments() {
    numlines(this,_,_,result)
  }

  /** The ration of lines of comments to total lines in this function (between 0.0 and 1.0) */
  float getCommentRatio() {
    if this.getNumberOfLines() = 0 then
      result = 0.0
    else
      result = ((float)this.getNumberOfLinesOfComments()) / ((float)this.getNumberOfLines())
  }

  /** the number of function calls (and, for Objective C, message expressions)
      in this function */
  int getNumberOfCalls() {
    // Checking that the name of the target exists is a workaround for a DB inconsistency
    result = count(FunctionCall c | c.getEnclosingFunction() = this and not (c.getTarget() instanceof Operator) and exists(c.getTarget().getName()))
           + count(MessageExpr me | me.getEnclosingFunction() = this)
  }

   /** Cyclomatic complexity:
       the number of branching statements (if, while, do, for,
       switch, case, catch) plus the number of branching
       expressions (?, &amp;&amp; and ||) plus one. */
   int getCyclomaticComplexity() {
     result = 1 + cyclomaticComplexityBranches(getBlock())
     and not this.isMultiplyDefined()
   }

  /** Branching complexity:
      this is a measure derived from cyclomatic complexity, but it reflects
      only the branches that make the code difficult to read (as opposed to
      cyclomatic complexity, which attempts to evaluate how difficult the code
      is to test).
   */
  int getBranchingComplexity() {
     result =
       count(IfStmt stmt | stmt.getEnclosingFunction() = this and not stmt.isInMacroExpansion()) +
       count(WhileStmt stmt | stmt.getEnclosingFunction() = this and not stmt.isInMacroExpansion()) +
       count(DoStmt stmt | stmt.getEnclosingFunction() = this and not stmt.isInMacroExpansion()) +
       count(ForStmt stmt | stmt.getEnclosingFunction() = this and not stmt.isInMacroExpansion()) +
       count(SwitchStmt stmt | stmt.getEnclosingFunction() = this and not stmt.isInMacroExpansion()) +
       1
     and not this.isMultiplyDefined()
  }

  int getAfferentCoupling() {
    result = count(Function f |
      exists(Locatable l |
        f.calls(this, l) or
        f.accesses(this, l)
      )
    )
  }

  int getEfferentCoupling() {
    result = count(Function f |
      exists(Locatable l |
        this.calls(f, l) or
        this.accesses(f, l)
      )
    )
  }

  /*
   * Halstead Metrics
   */

   /**
    *  Gets the Halstead "N1" metric: this is the total number of operators in
    *  this function. Operators are taken to be all operators in expressions
    *  (+, *, &amp;, ->, =, ...) as well as most statements
    */
   int getHalsteadN1() {
     result =
       1 + // account for the function itself
       count(Operation op | op.getEnclosingFunction() = this) +
       count(CommaExpr e | e.getEnclosingFunction() = this) +
       count(ReferenceToExpr e | e.getEnclosingFunction() = this) +
       count(PointerDereferenceExpr e | e.getEnclosingFunction() = this) +
       count(Cast e | e.getEnclosingFunction() = this) +
       count(SizeofOperator e | e.getEnclosingFunction() = this) +
       count(TypeidOperator e | e.getEnclosingFunction() = this) +
       count(ControlStructure s | s.getEnclosingFunction() = this) +
       count(JumpStmt s | s.getEnclosingFunction() = this) +
       count(ReturnStmt s | s.getEnclosingFunction() = this) +
       count(SwitchCase c | c.getEnclosingFunction() = this) +
       // Count the 'else' branches
       count(IfStmt s | s.getEnclosingFunction() = this and s.hasElse())
   }

   /**
    *  Gets the Halstead "N2" metric: this is the total number of operands in this
    *  function. An operand is either a variable, constant, type name or function name
    */
   int getHalsteadN2() {
     result =
       1 + // account for the function itself
       count(Access a | a.getEnclosingFunction() = this) +
       count(FunctionCall fc | fc.getEnclosingFunction() = this) +
       // Approximate: count declarations twice to account for the type name
       // and the identifier
       2 * count(Declaration d | d.getParentScope+() = this)
   }

   /**
    * Gets the Halstead "n1" metric: this is the total number of distinct operators
    * in this function. Operators (as in the N1 metric) are all operators in expressions
    * as well as most statements.
    */
   int getHalsteadN1Distinct() {
     exists(
       int comma, int refTo, int dereference, int cCast, int staticCast, int constCast, int reinterpretCast, int dynamicCast,
       int sizeofExpr, int sizeofType, int ifVal, int switchVal, int forVal, int doVal, int whileVal, int gotoVal, int continueVal,
       int breakVal, int returnVal, int caseVal, int elseVal |

       (if exists(CommaExpr e | e.getEnclosingFunction() = this) then comma = 1 else comma = 0) and
       (if exists(ReferenceToExpr e | e.getEnclosingFunction() = this) then refTo = 1 else refTo = 0) and
       (if exists(PointerDereferenceExpr e | e.getEnclosingFunction() = this) then dereference = 1 else dereference = 0) and
       (if exists(CStyleCast e | e.getEnclosingFunction() = this) then cCast = 1 else cCast = 0) and
       (if exists(StaticCast e | e.getEnclosingFunction() = this) then staticCast = 1 else staticCast = 0) and
       (if exists(ConstCast e | e.getEnclosingFunction() = this) then constCast = 1 else constCast = 0) and
       (if exists(ReinterpretCast e | e.getEnclosingFunction() = this) then reinterpretCast = 1 else reinterpretCast = 0) and
       (if exists(DynamicCast e | e.getEnclosingFunction() = this) then dynamicCast = 1 else dynamicCast = 0) and
       (if exists(SizeofExprOperator e | e.getEnclosingFunction() = this) then sizeofExpr = 1 else sizeofExpr = 0) and
       (if exists(SizeofTypeOperator e | e.getEnclosingFunction() = this) then sizeofType = 1 else sizeofType = 0) and
       (if exists(IfStmt e | e.getEnclosingFunction() = this) then ifVal = 1 else ifVal = 0) and
       (if exists(SwitchStmt e | e.getEnclosingFunction() = this) then switchVal = 1 else switchVal = 0) and
       (if exists(ForStmt e | e.getEnclosingFunction() = this) then forVal = 1 else forVal = 0) and
       (if exists(DoStmt e | e.getEnclosingFunction() = this) then doVal = 1 else doVal = 0) and
       (if exists(WhileStmt e | e.getEnclosingFunction() = this) then whileVal = 1 else whileVal = 0) and
       (if exists(GotoStmt e | e.getEnclosingFunction() = this) then gotoVal = 1 else gotoVal = 0) and
       (if exists(ContinueStmt e | e.getEnclosingFunction() = this) then continueVal = 1 else continueVal = 0) and
       (if exists(BreakStmt e | e.getEnclosingFunction() = this) then breakVal = 1 else breakVal = 0) and
       (if exists(ReturnStmt e | e.getEnclosingFunction() = this) then returnVal = 1 else returnVal = 0) and
       (if exists(SwitchCase e | e.getEnclosingFunction() = this) then caseVal = 1 else caseVal = 0) and
       (if exists(IfStmt s | s.getEnclosingFunction() = this and s.hasElse()) then elseVal = 1 else elseVal = 0)
     and
     result =
       1 + // account for the function itself
       count(string s | exists(Operation op | op.getEnclosingFunction() = this and s = op.getOperator())) +
       comma +
       refTo +
       dereference +
       cCast + staticCast + constCast + reinterpretCast + dynamicCast +
       sizeofExpr + sizeofType +
       ifVal + switchVal + forVal + doVal + whileVal +
       gotoVal + continueVal + breakVal +
       returnVal +
       caseVal +
       elseVal
     )
   }

   /**
    *  Gets the Halstead "n2" metric: this is the number of distinct operands in this
    *  function. An operand is either a variable, constant, type name or function name
    */
   int getHalsteadN2Distinct() {
     result =
       1 + // account for the function itself
       count(string s | exists(Access a | a.getEnclosingFunction() = this and s = a.getTarget().getName())) +
       count(Function f | exists(FunctionCall fc | fc.getEnclosingFunction() = this and f = fc.getTarget())) +
       // Approximate: count declarations once more to account for the type name
       count(Declaration d | d.getParentScope+() = this)
   }

   /**
    *  Gets the Halstead length of this function. This is the sum of the N1 and N2 Halstead metrics
    */
   int getHalsteadLength() {
     result = this.getHalsteadN1() + this.getHalsteadN2()
   }

   /**
    *  Gets the Halstead vocabulary size of this function. This is the sum of the n1 and n2 Halstead metrics
    */
   int getHalsteadVocabulary() {
     result = this.getHalsteadN1Distinct() + this.getHalsteadN2Distinct()
   }

   /**
    *  Gets the Halstead volume of this function. This is the Halstead size multiplied by the log of the
    *  Halstead vocabulary. It represents the information content of the function.
    */
   float getHalsteadVolume() {
     result = ((float)this.getHalsteadLength()) * this.getHalsteadVocabulary().log2()
   }

   /**
    * Gets the Halstead difficulty value of this function. This is proportional to the number of unique
    * operators, and further proportional to the ratio of total operands to unique operands.
    */
   float getHalsteadDifficulty() {
     result = (float)(this.getHalsteadN1Distinct() * this.getHalsteadN2()) / (float)(2 * this.getHalsteadN2Distinct())
   }

   /**
    * Gets the Halstead level of this function. This is the inverse of the difficulty of the function.
    */
   float getHalsteadLevel() {
     exists(float difficulty |
       difficulty = this.getHalsteadDifficulty() and
       if difficulty != 0.0 then result = 1.0 / difficulty else result = 0.0
     )
   }

   /**
    * Gets the Halstead implementation effort for this function. This is the product of the volume and difficulty
    */
   float getHalsteadEffort() {
     result = this.getHalsteadVolume() * this.getHalsteadDifficulty()
   }

   /**
    * Gets the Halstead 'delivered bugs' metric for this function. This metric correlates with the complexity of
    * the software, but is known to be an underestimate of bug counts.
    */
   float getHalsteadDeliveredBugs() {
     result = this.getHalsteadEffort().pow(2.0/3.0) / 3000.0
   }

   /**
    * The maximum nesting level of complex statements such as if, while in the function. A nesting depth of
    * 2 would mean that there is, for example, an if statement nested in another if statement.
    */
   int getNestingDepth() {
     result = max(Stmt s, int aDepth | s.getEnclosingFunction() = this and nestingDepth(s, aDepth) | aDepth)
     and not isMultiplyDefined()
   }

}

// Branching points in the sense of cyclomatic complexity are binary,
// so there should be a branching point for each non-default switch
// case (ignoring those that just fall through to the next case).
private
predicate branchingSwitchCase(SwitchCase sc) {
  not sc.isDefault() and
  not sc.getASuccessor() instanceof SwitchCase and
  not defaultFallThrough(sc)
}

private
predicate defaultFallThrough(SwitchCase sc) {
  sc.isDefault() or
  defaultFallThrough(sc.getAPredecessor())
}

/** A branching statement used for the computation of
    cyclomatic complexity */
private
predicate branchingStmt(Stmt stmt) {
  stmt instanceof IfStmt or
  stmt instanceof WhileStmt or
  stmt instanceof DoStmt or
  stmt instanceof ForStmt or
  branchingSwitchCase(stmt)
}

/** A branching expression used for the computation of
    cyclomatic complexity */
private
predicate branchingExpr(Expr expr) {
  expr instanceof NotExpr or
  expr instanceof LogicalAndExpr or
  expr instanceof LogicalOrExpr or
  expr instanceof ConditionalExpr
}

/** The number of branching statements and expressions
    in a block, for computing cyclomatic complexity */
int cyclomaticComplexityBranches(Block b) {
  result =
    count(Stmt stmt |
      branchingStmt(stmt) and b.getAChild+() = stmt
      and not stmt.isInMacroExpansion()) +
    count(Expr expr |
      branchingExpr(expr) and b.getAChild+() = expr.getEnclosingStmt()
      and not expr.isInMacroExpansion())
}

/** The parent of a statement, excluding some common cases that don't really make
    sense for nesting depth. An example is: "if (...) { } else if (...) { }: we don't
    consider the second if nested. Blocks are also skipped, as are parents that have
    the same location as the child (typically they come from macros). */
private
predicate realParent(Stmt inner, Stmt outer) {
  if skipParent(inner) then
     realParent(inner.getParentStmt(), outer)
  else
    outer = inner.getParentStmt()
}

private predicate startsAt(Stmt s, File f, int line, int col) {
  exists(Location loc | loc = s.getLocation() |
    f = loc.getFile() and
    line = loc.getStartLine() and
    col = loc.getStartColumn()
  )
}

private
predicate skipParent(Stmt s) {
  exists(Stmt parent | parent = s.getParentStmt() |
    (s instanceof IfStmt and parent.(IfStmt).getElse() = s)
    or
    parent instanceof Block
    or
    exists(File f, int startLine, int startCol |
      startsAt(s, f, startLine, startCol) and
      startsAt(parent, f, startLine, startCol)
    )
  )
}

private
predicate nestingDepth(Stmt s, int depth) {
  depth = count(Stmt enclosing | realParent+(s, enclosing))
}


