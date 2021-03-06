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

/** Provides helpers for OverflowStatic.ql */
import default

class ZeroAssignment extends AssignExpr
{
  ZeroAssignment() {
    this.getAnOperand() instanceof VariableAccess and
    this.getAnOperand() instanceof Zero
  }

  Variable assignedVariable() {
    result.getAnAccess() = this.getAnOperand()
  }
}

private predicate staticLimit(RelationalOperation op, Variable v, int limit)
{
  (
    op instanceof LTExpr and
    op.getLeftOperand() = v.getAnAccess() and
    op.getRightOperand().getValue().toInt() - 1 = limit
  ) or (
    op instanceof LEExpr and
    op.getLeftOperand() = v.getAnAccess() and
    op.getRightOperand().getValue().toInt() = limit
  )
}

private predicate simpleInc(IncrementOperation inc, Variable v)
{
  inc.getAChild() = v.getAnAccess()
}

/**
 * A `for` loop of the form `for (x = 0; x < limit; x++)` with no modification
 * of `x` in the body. Variations with `<=` and `++x` are allowed.
 */
class ClassicForLoop extends ForStmt
{
  ClassicForLoop() {
    exists(LocalVariable v |
      this.getInitialization().getAChild() instanceof ZeroAssignment and
      staticLimit(this.getCondition(), v, _) and
      simpleInc(this.getUpdate(), v) and
      not exists(VariableAccess access |
        access.isUsedAsLValue() and
        v.getAnAccess() = access and
        this.getStmt().getAChild*() = access.getEnclosingStmt()
      )
    )
  }

  /** Gets the loop variable. */
  LocalVariable counter() {
    simpleInc(this.getUpdate(), result)
  }

  /** Gets the maximum value that the loop variable may have inside the loop
   * body. The minimum is 0. */
  int limit() {
    staticLimit(this.getCondition(), _, result)
  }
}
