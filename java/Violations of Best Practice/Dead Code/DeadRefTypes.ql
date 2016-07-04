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
 * @name Unused classes and interfaces
 * @description A non-public class or interface that is not used anywhere in the program wastes
 *              programmer resources.
 * @kind problem
 * @problem.severity recommendation
 * @cwe 561
 */
import default
import semmle.code.java.Reflection

/**
 * A class or interface that is not used anywhere.
 */
predicate dead(RefType dead) {
    dead.fromSource() and
    // Nothing depends on this type.
    not exists(RefType s | s.getMetrics().getADependency() = dead) and

    // Exclude Struts or JSP classes (marked with Javadoc tags).
    not exists(JavadocTag tag, string x |
      tag = dead.getDoc().getJavadoc().getATag(x) and
      (x.matches("@struts%") or x.matches("@jsp%"))
    ) and
    // Exclude public types.
    not dead.isPublic() and
    // Exclude results that have a `main` method.
    not dead.getAMethod().hasName("main") and
    // Exclude results that are referenced in XML files.
    not exists(XMLAttribute xla | xla.getValue() = dead.getQualifiedName()) and
    // Exclude type variables.
    not dead instanceof BoundedType and
    // Exclude JUnit tests.
    not dead.getASupertype*().hasName("TestCase") and
    // Exclude enum types.
    not dead instanceof EnumType and
    // Exclude classes that look like they may be reflectively constructed.
    not dead.getAnAnnotation() instanceof ReflectiveAccessAnnotation and

    // Insist all source ancestors are dead as well.
    forall(RefType t | t.fromSource() and t = dead.getASupertype+() | dead(t))
}

from RefType t, string kind
where dead(t) and
      (
        (t instanceof Class and kind = "class") or
        (t instanceof Interface and kind = "interface")
      )
select t, "Unused " + kind + ": " + t.getName() + " is not referenced within this codebase. " +
  "If not used as an external API it should be removed."
