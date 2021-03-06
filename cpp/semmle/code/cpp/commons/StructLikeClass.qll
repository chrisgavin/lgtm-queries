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

import semmle.code.cpp.Class

/** A class that is either a struct or just has getters and setters
  * for its members. In either case it just stores data and has no
  * real encapsulation.
  */
class StructLikeClass extends Class {

  StructLikeClass() {
    this instanceof Struct
    or
    (
      forall(MemberFunction f | f = this.getAMemberFunction() |
        exists(MemberVariable v | setter(v, f, this) or getter(v, f, this)) or
        f instanceof Constructor or
        f instanceof Destructor or
        // Allow the copy assignment op - still struct-like
        f instanceof CopyAssignmentOperator
      )
    )
  }

  /** Get a setter function in this class, setting the given variable.
      This is a function called set... that assigns to this variable and no other
      member variable of the class. In addition, it takes a single parameter of
      type the type of the corresponding member variable. */
  MemberFunction getASetter(MemberVariable v) {
    setter(v, result, this)
  }

  /** Get a getter function in this class, getting the given variable.
      This is a function called get... that reads this variable and no other
      member variable of the class. In addition, its return type is the type
      of the corresponding member variable. */
  MemberFunction getAGetter(MemberVariable v) {
    setter(v, result, this)
  }

}

/** Setter member function. See StructLikeClass.getASetter */
predicate setter(MemberVariable v, MemberFunction f, Class c) {
    f.getDeclaringType() = c and
    v.getDeclaringType() = c and
    f.getName().matches("set%") and
    v.getAnAssignedValue().getEnclosingFunction() = f and
    not exists(MemberVariable v2 |
      v2.getDeclaringType() = c and
      v2.getAnAssignedValue().getEnclosingFunction() = f and
      v2 != v
    ) and
    f.getNumberOfParameters() = 1 and
    sameBaseType(f.getParameter(0).getType(), v.getType())
}

/** Getter member function. See StructLikeClass.getAGetter */
predicate getter(MemberVariable v, MemberFunction f, Class c) {
    f.getDeclaringType() = c and
    v.getDeclaringType() = c and
    f.getName().matches("get%") and
    v.getAnAccess().getEnclosingFunction() = f and
    not exists(MemberVariable v2 |
      v2.getDeclaringType() = c and
      v2.getAnAccess().getEnclosingFunction() = f and
      v2 != v
    ) and
    f.getNumberOfParameters() = 0 and
    sameBaseType(f.getType(), v.getType())
}

/** Same type up to typedefs, specifiers, and removing a single layer of pointers
    or references (but not arrays). Equates, eg. const int* with int, but not int** with int
    or int[] with int. */
predicate sameBaseType(Type t1, Type t2) {
  exists (Type base1, Type base2 |
    base1 = t1.getUnderlyingType().getUnspecifiedType() and
    base2 = t2.getUnspecifiedType().getUnspecifiedType() and
    (
      base1 = base2 or
      base1.(PointerType).getBaseType() = base2 or
      base2.(PointerType).getBaseType() = base1 or
      base1.(ReferenceType).getBaseType() = base2 or
      base2.(ReferenceType).getBaseType() = base1
    )
  )
}