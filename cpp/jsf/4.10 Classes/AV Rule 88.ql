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
 * @name Undisciplined multiple inheritance
 * @description Multiple inheritance should only be used in the following restricted form: n interfaces plus m private implementations, plus at most one protected implementation. Multiple inheritance can lead to complicated inheritance hierarchies that are difficult to comprehend and maintain.
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags changeability
 *       readability
 */
import default

/*
In the context of this rule, an interface is specified by a class which has the following properties:
- it is intended to be an interface,
- its public methods are pure virtual functions, and
- it does not hold any data, unless those data items are small and function as part of the interface (e.g. a unique object identifier).

An approximation of this definition is classes with pure virtual functions and less than 3 member variables.
*/
class InterfaceClass extends Class {
  InterfaceClass() {
     exists(MemberFunction m | m.getDeclaringType() = this and not compgenerated(m))
    and
     forall(MemberFunction m | m.getDeclaringType() = this and not compgenerated(m) | m instanceof PureVirtualFunction)
    and
     count(MemberVariable v | v.getDeclaringType() = this) < 3
  }
}

class InterfaceImplementor extends Class {
  InterfaceImplementor() {
    exists(ClassDerivation d | d.getDerivedClass() = this and d.getBaseClass() instanceof InterfaceClass)
  }
  int getNumInterfaces() {
    result = count(ClassDerivation d | d.getDerivedClass() = this and d.getBaseClass() instanceof InterfaceClass)
  }
  int getNumProtectedImplementations() {
    result = count(ClassDerivation d | d.hasSpecifier("protected") and d.getDerivedClass() = this and not d.getBaseClass() instanceof InterfaceClass)
  }
  int getNumPrivateImplementations() {
    result = count(ClassDerivation d | d.hasSpecifier("private") and d.getDerivedClass() = this and not d.getBaseClass() instanceof InterfaceClass)
  }
  int getNumPublicImplementations() {
    result = count(ClassDerivation d | d.hasSpecifier("public") and d.getDerivedClass() = this and not d.getBaseClass() instanceof InterfaceClass)
  }
}

from InterfaceImplementor d
where d.getNumPublicImplementations() > 0
  or d.getNumProtectedImplementations() > 1
select d, "Multiple inheritance should not be used with " + d.getNumInterfaces().toString()
   + " interfaces, " + d.getNumPrivateImplementations().toString() + " private implementations, " + d.getNumProtectedImplementations().toString() + " protected implementations, and "
   + d.getNumPublicImplementations().toString() + " public implementations."
