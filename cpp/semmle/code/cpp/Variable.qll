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

import semmle.code.cpp.Element
import semmle.code.cpp.exprs.Access
import semmle.code.cpp.Initializer

/**
 * A C/C++ variable.
 *
 * For local variables, there is a one-to-one correspondence between
 * `Variable` and `VariableDeclarationEntry`.
 *
 * For other types of variable, there is a one-to-many relationship between
 * `Variable` and `VariableDeclarationEntry`. For example, a `Parameter`
 * can have multiple declarations.
 */
class Variable extends Declaration, @variable {

  /** Gets the initializer of this variable, if any. */
  Initializer getInitializer() { result.getDeclaration() = this }

  /** Holds if this variable has an initializer. */
  predicate hasInitializer() { exists(this.getInitializer()) }

  /** Gets an access to this variable. */
  VariableAccess getAnAccess() { result.getTarget() = this }

  /**
   * Gets a specifier of this variable. This includes `extern`, `static`,
   * `auto`, `private`, `protected`, `public`. Specifiers of the *type* of
   * this variable, such as `const` and `volatile`, are instead accessed
   * through `this.getType().getASpecifier()`.
   */
  Specifier getASpecifier() { varspecifiers(this,result) }

  /** Gets an attribute of this variable. */
  Attribute getAnAttribute() { varattributes(this,result) }

  /** Holds if this variable is `const`. */
  predicate isConst() { this.getType().isConst() }

  /** Holds if this variable is `volatile`. */
  predicate isVolatile() { this.getType().isVolatile() }

  /** Gets the name of this variable. */
  string getName() { none() }

  /** Gets the type of this variable. */
  Type getType() { none() }

  /** Gets the type of this variable, after typedefs have been resolved. */
  Type getUnderlyingType() { result = this.getType().getUnderlyingType() }

  /**
   * Gets the type of this variable prior to deduction caused by the C++11
   * `auto` keyword.
   *
   * If the type of this variable was not declared with the C++11 `auto`
   * keyword, then this predicate does not hold.
   *
   * If the type of this variable is completely `auto`, then `result` is an
   * instance of `AutoType`. For example:
   *
   *   `auto four = 4;`
   *
   * If the type of this variable is partially `auto`, then a descendant of
   * `result` is an instance of `AutoType`. For example:
   *
   *   `const auto& c = container;`
   */
  Type getTypeWithAuto() { autoderivation(this, result) }

  /**
   * Holds if the type of this variable is declared using the C++ `auto`
   * keyword.
   */
  predicate declaredUsingAutoType() { autoderivation(this, _) }

  override VariableDeclarationEntry getADeclarationEntry() {
    result.getDeclaration() = this
  }

  override Location getADeclarationLocation() {
    result = getADeclarationEntry().getLocation()
  }

  override VariableDeclarationEntry getDefinition() {
    result = getADeclarationEntry() and
    result.isDefinition()
  }

  override Location getDefinitionLocation() {
    result = getDefinition().getLocation()
  }

  override Location getLocation() {
    if exists(getDefinition()) then
      result = this.getDefinitionLocation()
    else
      result = this.getADeclarationLocation()
  }

  /**
   * Gets an expression that is assigned to this variable somewhere in the
   * program.
   */
  Expr getAnAssignedValue() {
    result = this.getInitializer().getExpr()
    or
    exists (ConstructorFieldInit cfi
    | cfi.getTarget() = this and result = cfi.getExpr())
    or
    exists (AssignExpr ae
    | ae.getLValue().(Access).getTarget() = this and result = ae.getRValue())
  }

  /**
   * Gets an assignment expression that assigns to this variable.
   * For example: `x=...` or `x+=...`.
   */
  Assignment getAnAssignment() {
    result.getLValue() = this.getAnAccess()
  }

  /**
   * Holds if this is a compiler-generated variable. For example, a
   * [range-based for loop](http://en.cppreference.com/w/cpp/language/range-for)
   * typically has three compiler-generated variables, named `__range`,
   * `__begin`, and `__end`:
   *
   *    `for (char c : str) { ... }`
   */
  predicate isCompilerGenerated() { compgenerated(this) }
}

/**
 * A particular declaration or definition of a C/C++ variable.
 */
class VariableDeclarationEntry extends DeclarationEntry, @var_decl {
  override Variable getDeclaration() { result = getVariable() }

  /**
   * Gets the variable which is being declared or defined.
   */
  Variable getVariable() { var_decls(this,result,_,_,_) }

  /**
   * Gets the name, if any, used for the variable at this declaration or
   * definition.
   *
   * In most cases, this will be the name of the variable itself. The only
   * case in which it can differ is in a parameter declaration entry,
   * because the parameter may have a different name in the declaration
   * than in the definition. For example:
   *
   *    ```
   *    // Declaration. Parameter is named "x".
   *    int f(int x);
   *
   *    // Definition. Parameter is named "y".
   *    int f(int y) { return y; }
   *    ```
   */
  override string getName() { var_decls(this,_,_,result,_) and result != "" }

  /**
   * Gets the type of the variable which is being declared or defined.
   */
  override Type getType() { var_decls(this,_,result,_,_) }

  override Location getLocation() { var_decls(this,_,_,_,result) }

  /**
   * Holds if this is a definition of a variable.
   *
   * This always holds for local variables and member variables, but need
   * not hold for global variables. In the case of function parameters,
   * this holds precisely when the enclosing `FunctionDeclarationEntry` is
   * a definition.
   */
  override predicate isDefinition() { var_def(this) }

  override string getASpecifier() { var_decl_specifiers(this,result) }
}

/**
 * A parameter as described within a particular declaration or definition
 * of a C/C++ function.
 */
class ParameterDeclarationEntry extends VariableDeclarationEntry {
  ParameterDeclarationEntry() { param_decl_bind(this,_,_) }

  /**
   * Gets the function declaration or definition which this parameter
   * description is part of.
   */
  FunctionDeclarationEntry getFunctionDeclarationEntry() {
    param_decl_bind(this,_,result)
  }

  /**
   * Gets the zero-based index of this parameter.
   */
  int getIndex() { param_decl_bind(this,result,_) }

  override string toString() {
    if exists(getName())
      then result = super.toString()
      else exists (string idx
           | idx = ((getIndex() + 1).toString() + "th")
                 .replaceAll("1th","1st")
                 .replaceAll("2th","2nd")
                 .replaceAll("3th","3rd")
                 .replaceAll("11st","11th")
                 .replaceAll("12nd","12th")
                 .replaceAll("13rd","13th")
           | if exists(getCanonicalName())
               then result = "declaration of " + getCanonicalName() +
                             " as anonymous " + idx + " parameter"
               else result = "declaration of " + idx + " parameter")
  }

  /**
   * Gets the name of this `ParameterDeclarationEntry` including it's type.
   *
   * For example: "int p".
   */
  string getTypedName() {
    exists(string typeString, string nameString |
      if exists(getType().getName()) then typeString = getType().getName() else typeString = "" and
      if exists(getName()) then nameString = getName() else nameString = "" and
      if (typeString != "" and nameString != "") then (
        result = typeString + " " + nameString
      ) else (
        result = typeString + nameString
      )
    )
  }
}

/**
 * A C/C++ variable with block scope [N4140 3.3.3]. In other words, a local
 * variable or a function parameter.
 */
class LocalScopeVariable extends Variable, @localscopevariable {
  /** Gets the function to which this variable belongs. */
  abstract Function getFunction();
}

/**
 * DEPRECATED: use `LocalScopeVariable` instead.
 */
deprecated class StackVariable extends Variable {
  StackVariable() { this instanceof LocalScopeVariable }
  Function getFunction() {
    result = this.(LocalScopeVariable).getFunction()
  }
}

/**
 * A C/C++ local variable. In other words, any variable that has block
 * scope [N4140 3.3.3], but is not a function parameter.
 */
class LocalVariable extends LocalScopeVariable, @localvariable {
  LocalVariable() { localvariables(this,_,_) }

  override string getName() { localvariables(this,_,result) }

  override Type getType() { localvariables(this,result,_) }

  override Function getFunction() {
    exists(DeclStmt s | s.getADeclaration() = this and s.getEnclosingFunction() = result)
  }
}

/**
 * A C/C++ variable which has global scope or namespace scope.
 */
class GlobalOrNamespaceVariable extends Variable, @globalvariable {
  GlobalOrNamespaceVariable() { globalvariables(this,_,_) }

  override string getName() { globalvariables(this,_,result) }

  override Type getType() { globalvariables(this,result,_) }

  override Element getEnclosingElement() { none() }
}

/**
 * A C/C++ variable which has namespace scope.
 */
class NamespaceVariable extends GlobalOrNamespaceVariable {
  NamespaceVariable() {
    exists(Namespace n | namespacembrs(n, this))
  }
}

/**
 * A C/C++ variable which has global scope.
 *
 * Note that variables declared in anonymous namespaces have namespace scope,
 * even though they are accessed in the same manner as variables declared in
 * the enclosing scope of said namespace (which may be the global scope).
 */
class GlobalVariable extends GlobalOrNamespaceVariable {
  GlobalVariable() {
    not this instanceof NamespaceVariable
  }
}

/**
 * A C structure member or C++ member variable.
 *
 * This includes static member variables in C++. To exclude static member
 * variables, use `Field` instead of `MemberVariable`.
 */
class MemberVariable extends Variable, @membervariable {
  MemberVariable() { membervariables(this,_,_) and member(_,_,this) }

  /** Holds if this member is private. */
  predicate isPrivate() { this.hasSpecifier("private") }

  /** Holds if this member is protected. */
  predicate isProtected() { this.hasSpecifier("protected") }

  /** Holds if this member is public. */
  predicate isPublic() { this.hasSpecifier("public") }

  override string getName() { membervariables(this,_,result) }

  override Type getType() { membervariables(this,result,_) }

  /**
   * Holds if this variable is constructed from another variable (`v`) as a
   * result of template instantiation. It originates from a variable
   * declared in a template class.
   */
  predicate isConstructedFrom(MemberVariable v) {
    exists (Class c, Class d
    | d.isConstructedFrom(c) and
      this.getDeclaringType() = d and
      v.getDeclaringType() = c and
      v.getName() = this.getName())
  }

  /** Holds if this member is mutable. */
  predicate isMutable() {
    getADeclarationEntry().hasSpecifier("mutable")
  }
}

/**
 * A C/C++ function pointer variable.
 */
class FunctionPointerVariable extends Variable {
  FunctionPointerVariable() {
    this.getType() instanceof FunctionPointerType
  }
}

/**
 * A C/C++ function pointer member variable.
 */
class FunctionPointerMemberVariable extends MemberVariable {
  FunctionPointerMemberVariable() {
    this instanceof FunctionPointerVariable
  }
}
