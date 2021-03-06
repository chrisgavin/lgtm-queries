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
 * Provides classes for working with regular expression literals.
 *
 * Regular expressions are represented as an abstract syntax tree of regular expression
 * terms.
 */

import Locations
import Expr

/**
 * An element containing a regular expression term, that is, either
 * a regular expression literal or another regular expression term.
 */
class RegExpParent extends Locatable, @regexpparent {
}

/**
 * A regular expression term, that is, a syntactic part of a regular
 * expression literal.
 */
abstract class RegExpTerm extends Locatable, @regexpterm {
  override Location getLocation() {
    hasLocation(this, result)
  }

  /** Gets the `i`th child term of this term. */
  RegExpTerm getChild(int i) {
    regexpterm(result, _, this, i, _)
  }

  /** Gets a child term of this term. */
  RegExpTerm getAChild() {
    result = getChild(_)
  }

  /** Gets the number of child terms of this term. */
  int getNumChild() {
    result = count(getAChild())
  }

  /**
   * Gets the parent term of this regular expression term, or the
   * regular expression literal if this is the root term.
   */
  RegExpParent getParent() {
    regexpterm(this, _, result, _, _)
  }

  /** Gets the regular expression literal this term belongs to. */
  RegExpLiteral getLiteral() {
    result = getParent+()
  }

  override string toString() {
    regexpterm(this, _, _, _, result)
  }

  /** Holds if this regular expression term can match the empty string. */
  abstract predicate isNullable();

  /** Gets the regular expression term that is matched before this one, if any. */
  RegExpTerm getPredecessor() {
    exists (RegExpSequence seq, int i |
      seq.getChild(i) = this and
      seq.getChild(i-1) = result
    ) or
    result = ((RegExpTerm)getParent()).getPredecessor()
  }

  /** Gets the regular expression term that is matched after this one, if any. */
  RegExpTerm getSuccessor() {
    exists (RegExpSequence seq, int i |
      seq.getChild(i) = this and
      seq.getChild(i+1) = result
    ) or
    exists (RegExpTerm parent |
      parent = getParent() and
      not parent instanceof RegExpLookahead |
      result = parent.getSuccessor()
    )
  }
}

/** A quantified regular expression term. */
abstract class RegExpQuantifier extends RegExpTerm, @regexp_quantifier {
  /** Holds if the quantifier of this term is a greedy quantifier. */
  predicate isGreedy() {
    isGreedy(this)
  }
}

/**
 * An escaped regular expression term, that is, a regular expression
 * term starting with a backslash.
 */
abstract class RegExpEscape extends RegExpTerm, @regexp_escape {
}

/**
 * A constant regular expression term, that is, a regular expression
 * term matching a single string.
 */
class RegExpConstant extends RegExpTerm, @regexp_constant {
  /** Gets the string matched by this constant term. */
  string getValue() {
    regexpConstValue(this, result)
  }

  /**
   * Holds if this constant represents a valid Unicode character (as opposed
   * to a surrogate code point that does not correspond to a character by itself.)
   */
  predicate isCharacter() {
    any()
  }

  override predicate isNullable() {
    none()
  }
}

/** A character escape in a regular expression. */
class RegExpCharEscape extends RegExpEscape, RegExpConstant, @regexp_char_escape {
  override predicate isCharacter() {
    not (
      // unencodable characters are represented as '?' in the database
      getValue() = "?" and
      exists (string s | s = toString().toLowerCase() |
        // only Unicode escapes give rise to unencodable characters
        s.matches("\\u%") and
        // but '\u003f' actually is the '?' character itself
        s != "\\u003f"
      )
    )
  }
}

/** An alternative term, that is, a term of the form `a|b`. */
class RegExpAlt extends RegExpTerm, @regexp_alt {
  /** Gets an alternative of this term. */
  RegExpTerm getAlternative() {
    result = getAChild()
  }

  /** Gets the number of alternatives of this term. */
  int getNumAlternative() {
    result = getNumChild()
  }

  override predicate isNullable() {
    getAlternative().isNullable()
  }
}

/** A sequence term, that is, a term of the form `ab`. */
class RegExpSequence extends RegExpTerm, @regexp_seq {
  /** Gets an element of this sequence. */
  RegExpTerm getElement() {
    result = getAChild()
  }

  /** Gets the number of elements in this sequence. */
  int getNumElement() {
    result = getNumChild()
  }

  override predicate isNullable() {
    forall (RegExpTerm child | child = getAChild() | child.isNullable())
  }
}

/** A caret assertion `^` matching the beginning of a line. */
class RegExpCaret extends RegExpTerm, @regexp_caret {
  override predicate isNullable() {
    any()
  }
}

/** A dollar assertion `$` matching the end of a line. */
class RegExpDollar extends RegExpTerm, @regexp_dollar {
  override predicate isNullable() {
    any()
  }
}

/** A word boundary assertion `\b`. */
class RegExpWordBoundary extends RegExpTerm, @regexp_wordboundary {
  override predicate isNullable() {
    any()
  }
}

/** A non-word boundary assertion `\B`. */
class RegExpNonWordBoundary extends RegExpTerm, @regexp_nonwordboundary {
  override predicate isNullable() {
    any()
  }
}

/** A zero-width lookahead assertion. */
abstract class RegExpLookahead extends RegExpTerm {
  /** Gets the lookahead term. */
  RegExpTerm getOperand() {
    result = getAChild()
  }

  override predicate isNullable() {
    any()
  }
}

/** A positive-lookahead assertion, that is, a term of the form `(?=...)`. */
class RegExpPositiveLookahead extends RegExpLookahead, @regexp_positive_lookahead {
}

/** A negative-lookahead assertion, that is, a term of the form `(?!...)`. */
class RegExpNegativeLookahead extends RegExpLookahead, @regexp_negative_lookahead {
}

/** A star-quantified term, that is, a term of the form `...*`. */
class RegExpStar extends RegExpQuantifier, @regexp_star {
  override predicate isNullable() {
    any()
  }
}

/** A plus-quantified term, that is, a term of the form `...+`. */
class RegExpPlus extends RegExpQuantifier, @regexp_plus {
  override predicate isNullable() {
    getAChild().isNullable()
  }
}

/** An optional term, that is, a term of the form `...?`. */
class RegExpOpt extends RegExpQuantifier, @regexp_opt {
  override predicate isNullable() {
    any()
  }
}

/** A range-quantified term, that is, a term of the form `...{m,n}`. */
class RegExpRange extends RegExpQuantifier, @regexp_range {
  /** Gets the lower bound of the range, if any. */
  int getLowerBound() {
    rangeQuantifierLowerBound(this, result)
  }

  /** Gets the upper bound of the range, if any. */
  int getUpperBound() {
    rangeQuantifierUpperBound(this, result)
  }

  override predicate isNullable() {
    getAChild().isNullable() or
    getLowerBound() = 0
  }
}

/** A dot regular expression `.`. */
class RegExpDot extends RegExpTerm, @regexp_dot {
  override predicate isNullable() {
    none()
  }
}

/** A grouped regular expression, that is, a term of the form `(...)` or `(?:...)` */
class RegExpGroup extends RegExpTerm, @regexp_group {
  /** Holds if this is a capture group. */
  predicate isCapture() {
    isCapture(this, _)
  }

  /**
   * Gets the index of this capture group within the enclosing regular
   * expression literal.
   *
   * For example, in the regular expression `/((a?).)(?:b)/`, the
   * group `((a?).)` has index 1, the group `(a?)` nested inside it
   * has index 2, and the group `(?:b)` has no index, since it is
   * not a capture group.
   */
  int getNumber() {
    isCapture(this, result)
  }

  override predicate isNullable() {
    getAChild().isNullable()
  }
}

/** A normal character without special meaning in a regular expression. */
class RegExpNormalChar extends RegExpConstant, @regexp_normal_char {
}

/** A hexadecimal character escape such as `\x0a` in a regular expression. */
class RegExpHexEscape extends RegExpCharEscape, @regexp_hex_escape {
}

/** A unicode character escape such as `\u000a` in a regular expression. */
class RegExpUnicodeEscape extends RegExpCharEscape, @regexp_unicode_escape {
}

/** A decimal character escape such as `\0` in a regular expression. */
class RegExpDecimalEscape extends RegExpCharEscape, @regexp_dec_escape {
}

/** An octal character escape such as `\0177` in a regular expression. */
class RegExpOctalEscape extends RegExpCharEscape, @regexp_oct_escape {
}

/** A control character escape such as `\ca` in a regular expression. */
class RegExpControlEscape extends RegExpCharEscape, @regexp_ctrl_escape {
}

/** A character class escape such as `\w` or `\S` in a regular expression. */
class RegExpCharacterClassEscape extends RegExpEscape, @regexp_char_class_escape {
  /** Gets the name of the character class; for example, `w` for `\w`. */
  string getValue() {
    charClassEscape(this, result)
  }

  override predicate isNullable() {
    none()
  }
}

/** An identity escape such as `\\` or `\/` in a regular expression. */
class RegExpIdentityEscape extends RegExpCharEscape, @regexp_id_escape {
}

/** A back reference, that is, a term of the form `\i` in a regular expression. */
class RegExpBackRef extends RegExpTerm, @regexp_backref {
  /** Gets the number of the capture group this back reference refers to. */
  int getNumber() {
    backref(this, result)
  }

  /** Gets the capture group this back reference refers to. */
  RegExpGroup getGroup() {
    result.getLiteral() = this.getLiteral() and
    result.getNumber() = this.getNumber()
  }

  override predicate isNullable() {
    getGroup().isNullable()
  }
}

/** A character class, that is, a term of the form `[...]`. */
class RegExpCharacterClass extends RegExpTerm, @regexp_char_class {
  /** Holds if this is an inverted character class, that is, a term of the form `[^...]`. */
  predicate isInverted() {
    isInverted(this)
  }

  override predicate isNullable() {
    none()
  }
}

/** A character range in a character class in a regular expression. */
class RegExpCharacterRange extends RegExpTerm, @regexp_char_range {
  override predicate isNullable() {
    none()
  }
}

/** A parse error encountered while processing a regular expression literal. */
class RegExpParseError extends Error, @regexp_parse_error {
  /** Gets the regular expression term that triggered the parse error. */
  RegExpTerm getTerm() {
    regexpParseErrors(this, result, _)
  }

  /** Gets the regular expression literal in which the parse error occurred. */
  RegExpLiteral getLiteral() {
    result = getTerm().getLiteral()
  }

  override string getMessage() {
    regexpParseErrors(this, _, result)
  }

  override string toString() {
    result = getMessage()
  }
}
