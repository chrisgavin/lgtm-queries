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
 * @name Module-level cyclic import
 * @description Module uses member of cyclically imported module, which can lead to failure at import time.
 * @kind problem
 * @tags reliability
 *       correctness
 *       types
 * @problem.severity error
 * @sub-severity low
 * @precision high
 * @comprehension 0.5
 * @id py/unsafe-cyclic-import
 */

import python
import Cyclic

// This is a potentially crashing bug if
// 1. the imports in the whole cycle are lexically outside a def (and so executed at import time)
// 2. there is a use ('M.foo' or 'from M import foo') of the imported module that is lexically outside a def
// 3. 'foo' is defined in M after the import in M which completes the cycle.
// then if we import the 'used' module, we will reach the cyclic import, start importing the 'using'
// module, hit the 'use', and then crash due to the imported symbol not having been defined yet

from PythonModuleObject m1, Stmt imp, PythonModuleObject m2, string attr, Expr use, ControlFlowNode defn 
where failing_import_due_to_cycle(m1, m2, imp, defn, use, attr)
select use, "'" + attr + "' may not be defined if module $@ is imported before module $@, " +
"as the $@ of " + attr + " occurs after the cyclic $@ of " + m2.getName() + ".",
m1, m1.getName(), m2, m2.getName(), defn, "definition", imp, "import"

  