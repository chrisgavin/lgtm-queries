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
import semmle.code.cpp.Type
import semmle.code.cpp.metrics.MetricNamespace

/**
 * A C++ namespace.
 *
 * Note that namespaces are somewhat nebulous entities, as they do not in
 * general have a single well-defined location in the source code. The
 * related notion of a `NamespaceDeclarationEntry` is rather more concrete,
 * and should be used when a location is required. For example, the `std::`
 * namespace is particularly nebulous, as parts of it are defined across a
 * wide range of headers. As a more extreme example, the global namespace
 * is never explicitly declared, but might correspond to a large proportion
 * of the source code.
 */
class Namespace extends NameQualifyingElement, @namedscope, @namespace {

  /**
   * Gets the location of the namespace. Most namespaces do not have a
   * single well-defined source location, so a dummy location is returned,
   * unless the namespace has exactly one declaration entry.
   */
  override Location getLocation() {
    if strictcount(getADeclarationEntry()) = 1 then
      result = getADeclarationEntry().getLocation()
    else
    (
      result instanceof UnknownDefaultLocation
    )
  }

  /** Gets the simple name of this namespace. */
  override string getName() { namespaces(this,result) }

  /** Holds if this element is named `name`. */
  predicate hasName(string name) { name = this.getName() }

  /** Holds if the namespace is anonymous. */
  predicate isAnonymous() {
    hasName("(unnamed namespace)")
  }

  /** Gets the name of the parent namespace, if it exists. */
  private string getParentName() {
    result = this.getParentNamespace().getName() and
    result != ""
  }

  /** Gets the qualified name of this namespace. For example: `a::b`. */
  string getQualifiedName() {
    if exists (getParentName())
      then result = getParentNamespace().getQualifiedName() + "::" + getName()
      else result = getName()
  }

  /** Gets the parent namespace, if any. */
  Namespace getParentNamespace() {
    namespacembrs(result,this) or
    (not namespacembrs(_, this) and result instanceof GlobalNamespace)
  }

  /** Gets a child declaration of this namespace. */
  Declaration getADeclaration() { namespacembrs(this,result) }

  /** Gets a child namespace of this namespace. */
  Namespace getAChildNamespace() { namespacembrs(this,result) }

  /** Holds if this namespace may be from source. */
  predicate fromSource() { this.getADeclaration().fromSource() }

  /**
   * Holds if this namespace is in a library.
   *
   * DEPRECATED: never holds.
   */
  deprecated
  predicate fromLibrary() { not this.fromSource() }

  /** Gets the metric namespace. */
  MetricNamespace getMetrics() { result = this }

  override string toString() { result = this.getQualifiedName() }

  /** Gets a declaration of (part of) this namespace. */
  NamespaceDeclarationEntry getADeclarationEntry() {
    result.getNamespace() = this
  }

  /** Gets a file which declares (part of) this namespace. */
  File getAFile() {
    result = this.getADeclarationEntry().getLocation().getFile()
  }

}

/**
 * A declaration of (part of) a C++ namespace.
 *
 * This corresponds to a single `namespace N { ... }` occurrence in the
 * source code.
 */
class NamespaceDeclarationEntry extends Locatable, @namespace_decl {
  /**
   * Get the namespace that this declaration entry corresponds to.  There
   * is a one-to-many relationship between `Namespace` and
   * `NamespaceDeclarationEntry`.
   */
  Namespace getNamespace() { namespace_decls(this,result,_,_) }

  override string toString() { result = this.getNamespace().toString() }

  /**
   * Gets the location of the token preceding the namespace declaration
   * entry's body.
   *
   * For named declarations, such as "namespace MyStuff { ... }", this will
   * give the "MyStuff" token.
   *
   * For anonymous declarations, such as "namespace { ... }", this will
   * give the "namespace" token.
   */
  override Location getLocation() { namespace_decls(this,_,result,_) }

  /**
   * Gets the location of the namespace declaration entry's body. For
   * example: the "{ ... }" in "namespace N { ... }".
   */
  Location getBodyLocation() { namespace_decls(this,_,_,result) }
}

/**
 * A C++ `using` directive or `using` declaration.
 */
abstract class UsingEntry extends Locatable, @using {
  override Location getLocation() { usings(this,_,_,result) }
}

/**
 * A C++ `using` declaration. For example:
 *
 *   `using std::string;`
 */
class UsingDeclarationEntry extends UsingEntry {
  UsingDeclarationEntry() { not exists(Namespace n | usings(this,n,_,_)) }

  /**
   * Gets the declaration that is referenced by this using declaration. For
   * example, `std::string` in `using std::string`.
   */
  Declaration getDeclaration() { usings(this,result,_,_) }

  override string toString() {
    result = "using " + this.getDeclaration().toString()
  }
}

/**
 * A C++ `using` directive. For example:
 *
 *   `using namespace std;`
 */
class UsingDirectiveEntry extends UsingEntry {
  UsingDirectiveEntry() { exists(Namespace n | usings(this,n,_,_)) }

  /**
   * Gets the namespace that is referenced by this using directive. For
   * example, `std` in `using namespace std`.
   */
  Namespace getNamespace() { usings(this,result,_,_) }

  override string toString() {
    result = "using namespace " + this.getNamespace().toString()
  }
}

/**
 * Holds if `g` is an instance of `GlobalNamespace`. This predicate
 * is used suppress a warning in `GlobalNamespace.getADeclaration()`
 * by providing a fake use of `this`.
 */
private predicate suppressWarningForUnused(GlobalNamespace g) { any() }

/**
 * The C/C++ global namespace.
 */
class GlobalNamespace extends Namespace {

  GlobalNamespace() { this.hasName("") }

  override Declaration getADeclaration() {
    suppressWarningForUnused(this) and
    not exists(DeclStmt d |
      d.getADeclaration() = result and
      not result instanceof Function
    ) and
    not exists(ConditionDeclExpr cde | cde.getVariable() = result) and
    not exists(Enum e | e.getAnEnumConstant() = result) and
    not result instanceof Parameter and
    not result instanceof ProxyClass and
    not result instanceof TemplateParameter and
    not result instanceof LocalVariable and
    not namespacembrs(_, result) and
    not result.isMember()
  }

  /** Gets a child namespace of the global namespace. */
  override Namespace getAChildNamespace() {
    suppressWarningForUnused(this) and
    not (namespacembrs(result, _))
  }

  override Namespace getParentNamespace() {
    none()
  }

  /**
   * DEPRECATED: use `getName()`.
   */
  deprecated string getFullName() {
    result = this.getName()
  }

  override string toString() {
    result = "(global namespace)"
  }

}

/**
 * The C++ `std::` namespace.
 */
class StdNamespace extends Namespace {
  StdNamespace() {
    this.hasName("std") and this.getParentNamespace() instanceof GlobalNamespace
  }
}
