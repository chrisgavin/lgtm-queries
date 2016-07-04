// Copyright 2016 Semmle Ltd.
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
 * A library for working with Java annotations.
 *
 * Annotations are used to add meta-information to language elements in a
 * uniform fashion. They can be seen as typed modifiers that can take
 * parameters.
 *
 * Each annotation type has zero or more annotation elements that contain a
 * name and possibly a value.
 */

import Element
import Expr
import Type
import Member
import JDKAnnotations

/** Any annotation used to annotate language elements with meta-information. */
class Annotation extends @annotation, Expr {
  /** Whether this annotation applies to a declaration. */
  predicate isDeclAnnotation() { this instanceof DeclAnnotation }

  /** Whether this annotation applies to a type. */
  predicate isTypeAnnotation() { this instanceof TypeAnnotation }

  /** The element being annotated. */
  Element getAnnotatedElement() { this.getParent() = result }

  /** The annotation type declaration for this annotation. */
  AnnotationType getType() { result = Expr.super.getType() }

  /** The annotation element with the specified `name`. */
  AnnotationElement getAnnotationElement(string name) { 
    result = this.getType().getAnnotationElement(name)
  }

  /** A value of an annotation element. */
  Expr getAValue() { filteredAnnotValue(this, _, result) }

  /** The value of the annotation element with the specified `name`. */
  Expr getValue(string name) {
    filteredAnnotValue(this, this.getAnnotationElement(name), result)
  }
 
  /** The element being annotated. */
  Element getTarget() {
    exprs(this, _, _, result, _)
  } 

  /** A printable representation of this annotation. */
  string toString() { result = this.getType().getName() }

  /** This expression's Halstead ID (used to compute Halstead metrics). */
  string getHalsteadID() { result = "Annotation" }

  /**
   * A value of the annotation element with the specified `name`, which must be declared as an array
   * type.
   *
   * If the annotation element is defined with an array initializer, then the returned value will
   * be one of the elements of that array. Otherwise, the returned value will be the single
   * expression defined for the value.
   */
  Expr getAValue(string name) {
    getType().getAnnotationElement(name).getType() instanceof Array and
    exists(Expr value | value = getValue(name) |
      if value instanceof ArrayInit then
        result = value.(ArrayInit).getAnInit()
      else
        result = value
    )
  }
}

/** An `Annotation` that applies to a declaration. */
class DeclAnnotation extends @declannotation, Annotation {
}

/** An `Annotation` that applies to a type. */
class TypeAnnotation extends @typeannotation, Annotation {
}

/**
 * There may be duplicate entries in annotValue(...) - one entry for
 * information populated from bytecode, and one for information populated
 * from source. This removes the duplication.
 */
private
predicate filteredAnnotValue(Annotation a, Method m, Expr val)
{
  annotValue(a, m, val) and
  (sourceAnnotValue(a, m, val) or not sourceAnnotValue(a, m, _))
}

private
predicate sourceAnnotValue(Annotation a, Method m, Expr val)
{
  annotValue(a, m, val) and
  val.getFile().getExtension() = "java"
}

/** An abstract representation of language elements that can be annotated. */
class Annotatable extends Element {
  /** Whether this element has an annotation. */
  predicate hasAnnotation() { exists(Annotation a | a.getAnnotatedElement() = this) }

  /** Whether this element has the specified annotation. */
  predicate hasAnnotation(string package, string name) {
    exists(AnnotationType at | at = getAnAnnotation().getType() | at.nestedName() = name and at.getPackage().getName() = package)
  }

  /** An annotation that applies to this element. */
  Annotation getAnAnnotation() { result.getAnnotatedElement() = this }
  
  /**
   * Whether this or any enclosing `Annotatable` has a `@SuppressWarnings("<category>")`
   * annotation attached to it for the specified `category`.
   */
  predicate suppressesWarningsAbout(string category) {
    exists(string withQuotes 
      | withQuotes = ((SuppressWarningsAnnotation) getAnAnnotation()).getASuppressedWarning()
      | category = withQuotes.substring(1, withQuotes.length() - 1)
    ) or
    this.(Member).getDeclaringType().suppressesWarningsAbout(category) or
    this.(Expr).getEnclosingCallable().suppressesWarningsAbout(category) or
    this.(Stmt).getEnclosingCallable().suppressesWarningsAbout(category) or
    this.(NestedClass).getEnclosingType().suppressesWarningsAbout(category) or
    this.(LocalVariableDecl).getCallable().suppressesWarningsAbout(category)
  }
}

/** An annotation type is a special kind of interface type declaration. */
class AnnotationType extends Interface {
  AnnotationType() { isAnnotType(this) }

  /** The annotation element with the specified `name`. */
  AnnotationElement getAnnotationElement(string name) {
    methods(result,_,_,_,this,_) and result.hasName(name)
  }

  /** An annotation element that is a member of this annotation type. */
  AnnotationElement getAnAnnotationElement() {
    methods(result,_,_,_,this,_)
  }
  
  /** Whether this annotation type is annotated with the meta-annotation `@Inherited`. */
  predicate isInherited() {
    exists(Annotation ann |
      ann.getAnnotatedElement() = this and
      ann.getType().hasQualifiedName("java.lang.annotation", "Inherited")
    )
  }

  /** The path to the icon used when displaying query results. */
  string getIconPath() { result = "icons/annotation.png" }
}

/** An annotation element is a member declared in an annotation type. */
class AnnotationElement extends Member {
  AnnotationElement() { isAnnotElem(this) }

  /** The type of this annotation element. */
  Type getType() { methods(this,_,_,result,_,_) }
}
