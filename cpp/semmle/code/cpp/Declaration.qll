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
import semmle.code.cpp.Specifier
import semmle.code.cpp.Namespace

/**
 * A C/C++ declaration: for example, a variable declaration, a type
 * declaration, or a function declaration.
 *
 * This file defines two closely related classes: `Declaration` and
 * `DeclarationEntry`. Some declarations do not correspond to a unique
 * location in the source code. For example, a global variable might
 * be declared in multiple source files:
 *
 *   extern int myglobal;
 *
 * Each of these declarations is given its own distinct `DeclarationEntry`,
 * but they all share the same `Declaration`.
 *
 * Some derived class of `Declaration` do not have a corresponding
 * `DeclarationEntry`, because they always have a unique source location.
 * `EnumConstant` and `FriendDecl` are both examples of this.
 */
abstract class Declaration extends Locatable, @declaration {
  /**
   * Gets the innermost namespace which contains this declaration.
   *
   * The result will either be GlobalNamespace, or the tightest lexically
   * enclosing namespace block. In particular, note that for declarations
   * within structures, the namespace of the declaration is the same as the
   * namespace of the structure.
   */
  Namespace getNamespace() {
    // Top level declaration in a namespace ...
    result.getADeclaration() = this

    // ... or nested in another structure.
    or
    exists (Declaration m
    | m = this and result = m.getDeclaringType().getNamespace())
    or
    exists (EnumConstant c
    | c = this and result = c.getDeclaringEnum().getNamespace())
    or
    exists (Parameter p
    | p = this and result = p.getFunction().getNamespace())
    or
    exists (LocalVariable v
    | v = this and result = v.getFunction().getNamespace())
  }

  /**
   * Gets the name of the declaration, fully qualified with its
   * namespace. For example: "A::B::C::myfcn".
   */
  string getQualifiedName() {
    // MemberFunction, MemberVariable, MemberType
    exists (Declaration m
    | m = this and
      result = m.getDeclaringType().getQualifiedName() + "::" + m.getName())
    or
    exists (EnumConstant c
    | c = this and
      result = c.getDeclaringEnum().getQualifiedName() + "::" + c.getName())
    or
    exists (GlobalVariable v, string s1, string s2
    | v = this and
      s2 = v.getNamespace().getQualifiedName() and
      s1 = v.getName()
    | (s2 != "" and result = s2 + "::" + s1) or (s2 = "" and result = s1))
    or
    exists (Function f, string s1, string s2
    | f = this and f.isTopLevel() and
      s2 = f.getNamespace().getQualifiedName() and
      s1 = f.getName()
    | (s2 != "" and result = s2 + "::" + s1) or (s2 = "" and result = s1))
    or
    exists (UserType t, string s1, string s2
    | t = this and t.isTopLevel() and
      s2 = t.getNamespace().getQualifiedName() and
      s1 = t.getName()
    | (s2 != "" and result = s2 + "::" + s1) or (s2 = "" and result = s1))
  }

  predicate hasQualifiedName(string name) {
    this.getQualifiedName() = name
  }

  override string toString() { result = this.getName() }

  /** Gets the name of this declaration. */
  abstract string getName();
  predicate hasName(string name) { name = this.getName() }

  /** Holds if this element has the given name in the global namespace. */
  predicate hasGlobalName(string name) {
    hasName(name)
    and getNamespace() instanceof GlobalNamespace
  }

  /** Gets a specifier of this declaration. */
  abstract Specifier getASpecifier();

  /** Holds if this declaration has a specifier with the given name. */
  predicate hasSpecifier(string name) {
    this.getASpecifier().hasName(name)
  }

  /**
   * Gets a declaration entry corresponding to this declaration. See the
   * comment above this class for an explanation of the relationship
   * between `Declaration` and `DeclarationEntry`.
   */
  DeclarationEntry getADeclarationEntry() {
    none()
  }

  /**
   * Gets the location of a declaration entry corresponding to this
   * declaration.
   */
  abstract Location getADeclarationLocation();

  /**
   * Gets the declaration entry corresponding to this declaration that is a
   * definition, if any.
   */
  DeclarationEntry getDefinition() {
    none()
  }

  /** Gets the location of the definition, if any. */
  abstract Location getDefinitionLocation();

  /** Holds if the declaration has a definition. */
  predicate hasDefinition() { exists(this.getDefinition()) }
  predicate isDefined() { hasDefinition() }

  /** Gets the preferred location of this declaration, if any. */
  override Location getLocation() {
    none()
  }

  /** Gets a file where this element occurs. */
  File getAFile() { result = this.getADeclarationLocation().getFile() }

  /** Holds if this declaration is a top-level declaration. */
  predicate isTopLevel() {
    not (this.isMember() or
    this instanceof EnumConstant or
    this instanceof Parameter or
    this instanceof ProxyClass or
    this instanceof LocalVariable or
    this instanceof TemplateParameter or
    this.(UserType).isLocal())
  }

  /** Holds if this declaration is static. */
  predicate isStatic() { this.hasSpecifier("static") }

  /** Holds if this declaration is a member of a class/struct/union. */
  predicate isMember() { hasDeclaringType() }

  /** Holds if this declaration is a member of a class/struct/union. */
  predicate hasDeclaringType() {
    exists(this.getDeclaringType())
  }

  /** Gets the class where this member is declared, if it is a member. */
  Class getDeclaringType() { member(result,_,this) }
}

/**
 * A C/C++ declaration entry. See the comment above `Declaration` for an
 * explanation of the relationship between `Declaration` and
 * `DeclarationEntry`.
 */
abstract class DeclarationEntry extends Locatable {
  /** a specifier associated with this declaration entry */
  abstract string getASpecifier();

  /**
   * Gets the name associated with the corresponding definition (where
   * available), or the name declared by this entry otherwise.
   */
  string getCanonicalName() {
    if getDeclaration().isDefined() then
      result = getDeclaration().getDefinition().getName()
    else
      result = getName()
  }

  /**
   * Gets the declaration for which this is a declaration entry.
   *
   * Note that this is *not* always the inverse of
   * Declaration.getADeclarationEntry(), for example if C is a
   * TemplateClass, I is an instantiation of C, and D is a Declaration of
   * C, then:
   *  C.getADeclarationEntry() returns D
   *  I.getADeclarationEntry() returns D
   *  but D.getDeclaration() only returns C
   */
  abstract Declaration getDeclaration();

  /** Gets the name associated with this declaration entry, if any. */
  abstract string getName();

  /**
   * Gets the type associated with this declaration entry.
   *
   * For variable declarations, get the type of the variable.
   * For function declarations, get the return type of the function.
   * For type declarations, get the type being declared.
   */
  abstract Type getType();

  /**
   * Holds if this declaration entry has a specifier with the given name.
   */
  predicate hasSpecifier(string specifier) {
    getASpecifier() = specifier
  }

  /** Holds if this declaration entry is a definition. */
  abstract predicate isDefinition();

  override string toString() {
    if isDefinition() then
      result = "definition of " + getName()
    else if getName() = getCanonicalName() then
      result = "declaration of " + getName()
    else
      result = "declaration of " + getCanonicalName() + " as " + getName()
  }
}


/**
 * A declaration that can potentially have more C++ access rights than its
 * enclosing element. This comprises `Class` (they have access to their own
 * private members) along with other `UserType`s and `Function` (they can be
 * the target of `friend` declarations).
 *
 * In the C++ standard (N4140 11.2), rules for access control revolve around
 * the informal phrase "_R_ occurs in a member or friend of class C", where
 * `AccessHolder` corresponds to this _R_.
 */
abstract class AccessHolder extends Declaration {
  /**
   * Holds if `this` can access private members of class `c`.
   *
   * This predicate encodes the phrase "occurs in a member or friend" that is
   * repeated many times in the C++14 standard, section 11.2.
   */
  predicate inMemberOrFriendOf(Class c) {
    (
      this.getEnclosingAccessHolder*() = c
    ) or (
      exists(FriendDecl fd | fd.getDeclaringClass() = c |
        this.getEnclosingAccessHolder*() = fd.getFriend()
      )
    )
  }

  /**
   * Gets the nearest enclosing AccessHolder.
   */
  abstract AccessHolder getEnclosingAccessHolder();

  /**
   * Holds if a base class `base` of `derived` _is accessible at_ `this` (N4140
   * 11.2/4). When this holds, and `derived` has only one base subobject of
   * type `base`, code in `this` can implicitly convert a pointer to `derived`
   * into a pointer to `base`. Conversely, if such a conversion is possible
   * then this predicate holds.
   *
   * For the sake of generality, this predicate also holds whenever `base` =
   * `derived`.
   *
   * This predicate is `pragma[inline]` because it is infeasible to fully
   * compute it on large code bases: all classes `derived` can be converted to
   * their public bases `base` from everywhere (`this`), so this predicate
   * could yield a number of tuples that is quadratic in the size of the
   * program. To avoid this combinatorial explosion, only use this predicate in
   * a context where `this` together with `base` or `derived` are sufficiently
   * restricted.
   */
  pragma[inline]
  predicate canAccessClass(Class base, Class derived) {
    // This predicate is marked `inline` and implemented in a very particular
    // way. If we allowed this predicate to be fully computed, it would relate
    // all `AccessHolder`s to all classes, which would be too much.

    // There are four rules in N4140 11.2/4. Only the one named (4.4) is
    // recursive, and it describes a transitive closure: intuitively, if A can
    // be converted to B, and B can be converted to C, then A can be converted
    // to C. To limit the number of tuples in the non-inline helper predicates,
    // we first separate the derivation of 11.2/4 into two cases:

    // Derivations using only (4.1) and (4.4). Note that these derivations are
    // independent of `this`, which is why users of this predicate must take
    // care to avoid a combinatorial explosion.
    isDirectPublicBaseOf*(base, derived)
    or
    // Derivations using (4.2) or (4.3) at least once.
    this.thisCanAccessClassTrans(base, derived)
  }

  /**
   * Holds if a base class `base` of `derived` _is accessible at_ `this` when
   * the derivation of that fact uses rule (4.2) and (4.3) of N4140 11.2/4 at
   * least once. In other words, the `this` parameter is not ignored. This
   * restriction makes it feasible to fully enumerate this predicate even on
   * large code bases.
   */
  private predicate thisCanAccessClassTrans(Class base, Class derived) {
    // This implementation relies on the following property of our predicates:
    // if `this.thisCanAccessClassStep(b, d)` and
    // `isDirectPublicBaseOf(b2, b)`, then
    // `this.thisCanAccessClassStep(b2, d)`. In other words, if a derivation
    // uses (4.2) or (4.3) somewhere and uses (4.1) directly above that in the
    // transitive chain, then the use of (4.1) is redundant. This means we only
    // need to consider derivations that use (4.2) or (4.3) as the "first"
    // step, that is, towards `base`, so this implementation is essentially a
    // transitive closure with a restricted base case.
    this.thisCanAccessClassStep(base, derived)
    or
    exists(Class between | thisCanAccessClassTrans(base, between) |
      isDirectPublicBaseOf(between, derived) or
      this.thisCanAccessClassStep(between, derived)
    )

    // It is possible that this predicate could be computed faster for deep
    // hierarchies if we can prove and exploit that all derivations of 11.2/4
    // can be broken down into steps where `base` is a _direct_ base of
    // `derived` in each step.
  }

  /**
   * Holds if a base class `base` of `derived` _is accessible at_ `this` using
   * only a single application of rule (4.2) and (4.3) of N4140 11.2/4.
   */
  private predicate thisCanAccessClassStep(Class base, Class derived) {
    exists(AccessSpecifier public | public.hasName("public") |
      // Rules (4.2) and (4.3) are implemented together as one here with
      // reflexive-transitive inheritance, where (4.3) is the transitive case,
      // and (4.2) is the reflexive case.
      exists(Class p | p = derived.getADerivedClass*() |
        this.inMemberOrFriendOf(p) and
        // Note: it's crucial that this is `!=` rather than `not =` since
        // accessOfBaseMember does not have a result when the member would be
        // inaccessible.
        p.accessOfBaseMember(base, public) != public
      )
    ) and
    // This is the only case that doesn't in itself guarantee that
    // `derived` < `base`, so we add the check here. The standard suggests
    // computing `canAccessClass` only for derived classes, but that seems
    // incompatible with the execution model of QL, so we instead construct
    // every case to guarantee `derived` < `base`.
    derived = base.getADerivedClass+()
  }

  /**
   * Holds if a non-static member `member` _is accessible at_ `this` when named
   * in a class `derived` that is derived from or equal to the declaring class
   * of `member` (N4140 11.2/5 and 11.4).
   *
   * This predicate determines whether an expression `x.member` would be
   * allowed in `this` when `x` has type `derived`. The more general syntax
   * `x.N::member`, where `N` may be a base class of `derived`, is not
   * supported. This should only affect very rare edge cases of 11.4. This
   * predicate concerns only _access_ and thus does not determine whether
   * `member` can be unambiguously named at `this`: multiple overloads may
   * apply, or `member` may be declared in an ambiguous base class.
   *
   * This predicate is `pragma[inline]` because it is infeasible to fully
   * compute it on large code bases: all public members `member` are accessible
   * from everywhere (`this`), so this predicate could yield a number of tuples
   * that is quadratic in the size of the program. To avoid this combinatorial
   * explosion, only use this predicate in a context where `this` and `member`
   * are sufficiently restricted when `member` is public.
   */
  pragma[inline]
  predicate canAccessMember(Declaration member, Class derived) {
    this.couldAccessMember(
      member.getDeclaringType(),
      member.getASpecifier().(AccessSpecifier),
      derived
    )
  }

  /**
   * Holds if a hypothetical non-static member of `memberClass` with access
   * specifier `memberAccess` _is accessible at_ `this` when named in a class
   * `derived` that is derived from or equal to `memberClass` (N4140 11.2/5 and
   * 11.4).
   *
   * This predicate determines whether an expression `x.m` would be
   * allowed in `this` when `x` has type `derived` and `m` has `memberAccess`
   * in `memberClass`. The more general syntax `x.N::n`, where `N` may be a
   * base class of `derived`, is not supported. This should only affect very
   * rare edge cases of 11.4.
   *
   * This predicate is `pragma[inline]` because it is infeasible to fully
   * compute it on large code bases: all classes `memberClass` have their
   * public members accessible from everywhere (`this`), so this predicate
   * could yield a number of tuples that is quadratic in the size of the
   * program. To avoid this combinatorial explosion, only use this predicate in
   * a context where `this` and `memberClass` are sufficiently restricted when
   * `memberAccess` is public.
   */
  pragma[inline]
  predicate couldAccessMember(Class memberClass, AccessSpecifier memberAccess,
                              Class derived)
  {
    // There are four rules in N4140 11.2/5. To limit the number of tuples in
    // the non-inline helper predicates, we first separate the derivation of
    // 11.2/5 into two cases:

    // Rule (5.1) directly: the member is public, and `derived` uses public
    // inheritance all the way up to `memberClass`. Note that these derivations
    // are independent of `this`, which is why users of this predicate must
    // take care to avoid a combinatorial explosion.
    everyoneCouldAccessMember(memberClass, memberAccess, derived)
    or
    // Any other derivation.
    this.thisCouldAccessMember(memberClass, memberAccess, derived)
  }

  /**
   * Like `couldAccessMember` but only contains derivations in which either
   * (5.2), (5.3) or (5.4) must be invoked. In other words, the `this`
   * parameter is not ignored. This restriction makes it feasible to fully
   * enumerate this predicate even on large code bases. We check for 11.4 as
   * part of (5.3), since this further limits the number of tuples produced by
   * this predicate.
   */
  private predicate thisCouldAccessMember(Class memberClass,
                                          AccessSpecifier memberAccess,
                                          Class derived)
  {
    // Only (5.4) is recursive, and chains of invocations of (5.4) can always
    // be collapsed to one invocation by the transitivity of 11.2/4.
    // Derivations not using (5.4) can always be rewritten to have a (5.4) rule
    // in front because our encoding of 11.2/4 in `canAccessClass` is
    // reflexive. Thus, we only need to consider three cases: rule (5.4)
    // followed by either (5.1), (5.2) or (5.3).

    // Rule (5.4), using a non-trivial derivation of 11.2/4, followed by (5.1).
    // If the derivation of 11.2/4 is trivial (only uses (4.1) and (4.4)), this
    // case can be replaced with purely (5.1) and thus does not need to be in
    // this predicate.
    exists(Class between | this.thisCanAccessClassTrans(between, derived) |
      everyoneCouldAccessMember(memberClass, memberAccess, between)
    )
    or
    // Rule (5.4) followed by Rule (5.2)
    exists(Class between | this.canAccessClass(between, derived) |
        between.accessOfBaseMember(memberClass, memberAccess)
               .hasName("private") and
        this.inMemberOrFriendOf(between)
    )
    or
    // Rule (5.4) followed by Rule (5.3), integrating 11.4. We integrate 11.4
    // here because we would otherwise generate too many tuples. This code is
    // very performance-sensitive, and any changes should be benchmarked on
    // LibreOffice.

    // Rule (5.4) requires that `this.canAccessClass(between, derived)`
    // (implying that `derived <= between` in the class hierarchy) and that
    // `p <= between`. Rule 11.4 additionally requires `derived <= p`, but just
    // requiring that directly will trigger an optimizer bug (CORE-154).
    // Instead, we split into three cases for how `between` as a base of
    // `derived` is accessible at `this`, where `this` is the implementation of
    // `p`:
    // 1. `between` is an accessible base of `derived` by going through `p` as
    //    an intermediate step.
    // 2. `this` is part of the implementation of `derived` because it's a
    //    member or a friend. In this case, we do not need `p` to perform this
    //    derivation, so we can set `p = derived` and proceed as in case 1.
    // 3. `derived` has an alternative inheritance path up to `between` that
    //    bypasses `p`. Then that path must be public, or we are in case 2.
    exists(AccessSpecifier public | public.hasName("public") |
      exists(Class between, Class p |
        between.accessOfBaseMember(memberClass, memberAccess)
               .hasName("protected") and
        this.inMemberOrFriendOf(p) and
        (
          // This is case 1 from above. If `p` derives privately from `between`
          // then the member we're trying to access is private or inaccessible
          // in `derived`, so either rule (5.2) applies instead, or the member
          // is inaccessible. Therefore, in this case, `p` must derive at least
          // protected from `between`. Further, since the access of `derived`
          // to its base `between` must pass through `p` in this case, we know
          // that `derived` must derived publicly from `p` unless we are in
          // case 2; there are no other cases of 11.2/4 where the
          // implementation of a base class can access itself as a base.
          p.accessOfBaseMember(between, public).getName() >= "protected" and
          derived.accessOfBaseMember(p, public) = public
        or
          // This is case 3 above.
          derived.accessOfBaseMember(between, public) = public and
          derived = p.getADerivedClass*() and
          exists(p.accessOfBaseMember(between, memberAccess))
        )
      )
    )
  }

}

/**
 * Holds if `base` is a direct public base of `derived`, possibly virtual and
 * possibly through typedefs. The transitive closure of this predicate encodes
 * derivations of N4140 11.2/4 that use only (4.1) and (4.4).
 */
private predicate isDirectPublicBaseOf(Class base, Class derived) {
  exists(ClassDerivation cd |
    cd.getBaseClass() = base and
    cd.getDerivedClass() = derived and
    cd.getASpecifier().hasName("public")
  )
}

/**
 * Holds if a hypothetical member of `memberClass` with access specifier
 * `memberAccess` would be public when named as a member of `derived`.
 * This encodes N4140 11.2/5 case (5.1).
 */
private predicate everyoneCouldAccessMember(Class memberClass,
                                            AccessSpecifier memberAccess,
                                            Class derived)
{
  derived.accessOfBaseMember(memberClass, memberAccess).hasName("public")
}
