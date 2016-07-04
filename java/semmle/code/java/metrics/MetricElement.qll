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
 * A library for computing metrics on Java elements.
 */

import semmle.code.java.Element
import semmle.code.java.Type

/** This class provides access to metrics information for elements in Java programs. */
class MetricElement extends Element {

  /**
   * A dependency of this element, intended to be overridden by subclasses,
   * for use with the "level metric".
   *
   * The level metric is originally due to John Lakos, in his
   * book "Large-Scale C++ Software Design". It gives insight into
   * how deeply program elements are embedded in a particular
   * application.
   *
   * It assumes an abstract notion of dependency, which is
   * encoded via this method. Different elements have different
   * notions of dependency, so this method is overridden in subtypes.
   * It is typically a nondeterministic method, as an element may
   * depend on multiple other elements.
   */
  MetricElement getADependency() {
    result = this 
  }

  /** A dependency of this element that is from source. */
  MetricElement getADependencySrc() {
    result = this.getADependency() and result.fromSource()
  }

  /**
   * An element has no level defined if it is cyclically dependent
   * on itself. Otherwise, it has:
   *
   * - level 0, if it does not depend on any other elements,
   * - level 1, if it does not directly depend on another element
   * that occurs in the source, and
   * - level n+1, if it depends on another element at level n.
   *
   * Note that according to this definition, an element may have
   * multiple levels.
   */
  int getALevel() {
    this.fromSource() and
    not(this.getADependencySrc+() = this) and 
    (
      (not(exists(MetricElement t | t = this.getADependency())) and result = 0)
      or
      (not(this.getADependency().fromSource()) and
        exists(MetricElement e | this.getADependency() = e) and
        result=1)
      or
      (result = this.getADependency().getALevel() + 1)
    )
  }

  /** John Lakos' level metric. */
  int getLevel() {
    result = max(int d | d = this.getALevel())
  }

  /** The Halstead length of this element. This default implementation must be overridden in subclasses. */
  int getHalsteadLength() { result = 0 and none() }
  /** The Halstead vocabulary of this element. This default implementation must be overridden in subclasses. */
  int getHalsteadVocabulary() { result = 0 and none() }
  /** The cyclomatic complexity of this element. This default implementation must be overridden in subclasses. */
  int getCyclomaticComplexity() { result = 0 and none() }
  /** The percentage of comments in this element. This default implementation must be overridden in subclasses. */
  float getPercentageOfComments() { result = 0 and none() }

  /**
   * The Halstead volume is the product of Halstead length and
   * binary logarithm of Halstead vocabulary.
   */
  float getHalsteadVolume() {
    result = this.getHalsteadLength() * this.getHalsteadVocabulary().maximum(2.0).log2()
  }

  /** The maintainability index without comment weight. */
  float getMaintainabilityIndexWithoutComments() {
    result = 171 - 5.2 * this.getHalsteadVolume().log()
                 - 0.23 * this.getCyclomaticComplexity()
                 - 16.2 * this.getNumberOfLinesOfCode().log()
  }

  /** The maintainability index comment weight. */
  float getMaintainabilityIndexCommentWeight() {
   result = 50 * (2.4 * this.getPercentageOfComments()).sqrt().sin()
  }

  /**
   * The maintainability index is a composite number expressing the ease of
   * maintainability of a program or one of its components.
   *
   * In order to compute the maintainability index, a metric element needs
   * to provide methods that compute the element's Halstead volume,
   * cyclomatic complexity, average number of lines of code, and its
   * percentage of comments.
   *
   * The default implementations in this class simply fail. Classes
   * `MetricRefType` and `MetricCallable` provide concrete implementations.
   */
  float getMaintainabilityIndex() {
    result =   this.getMaintainabilityIndexWithoutComments() 
             + this.getMaintainabilityIndexCommentWeight()
  }
}

/* ========================================================================= */
/*                      METRICS LIBRARY                                      */
/* ========================================================================= */

/* QL metrics definitions. References for metrics defined here:

   http://en.wikipedia.org/wiki/Software_package_metrics

   Brian Henderson-Sellers (1996).
   Object-oriented Metrics - Measures of Complexity.
   Prentice Hall. ISBN 0-13-239872-9

   Robert Cecil Martin (2002).
   Agile Software Development: Principles, Patterns and Practices.
   Pearson Education. ISBN 0-13-597444-5.

   John Lakos (1996).
   Large-scale C++ Software Design
   Addison-Wesley Professional. ISBN 0-20-163362-0.

   Diomidis Spinellis (2006).
   Code Quality: The Open Source Perspective.
   Addison Wesley. ISBN 0-321-16607-8.

   Objecteering:
   http://www.objecteering.com/

   NDepend:
   http://ndepend.com/

   Virtual Machinery JHawk:
   http://www.virtualmachinery.com/jhawkmetrics.htm

   Eclipse metrics plugins:
   http://metrics.sourceforge.net/
   http://eclipse-metrics.sourceforge.net/

   Avoisto Project Analyzer:
   http://www.aivosto.com/project/help/pm-oo-ck.html

   ckjm: Chidamber and Kemerer Java Metrics:
   http://www.spinellis.gr/sw/ckjm/
*/
