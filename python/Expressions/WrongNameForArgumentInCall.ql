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
 * @name Wrong name for an argument in a call
 * @description A call to function may name an argument for a parameter that does not exist. This will cause a TypeError to be raised.
 * @kind problem
 * @tags reliability
 *       correctness
 * @problem.severity error
 * @sub-severity low
 * @precision very-high
 * @id py/call/wrong-named-argument
 */

import python
import Expressions.CallArgs


from Call call, FunctionObject func, string name
where
illegally_named_parameter(call, func, name) and
not func.isAbstract() and
not exists(FunctionObject overridden | func.overrides(overridden) and overridden.getFunction().getAnArg().(Name).getId() = name)
select
call, "Keyword argument '" + name + "' is not a supported parameter name of $@.", func, func.descriptiveString()
