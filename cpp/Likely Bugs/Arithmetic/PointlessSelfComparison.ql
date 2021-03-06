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
 * @name Self comparison
 * @description Comparing a variable to itself always produces the
                same result, unless the purpose is to check for
                integer overflow or floating point NaN.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags readability
 *       maintainability
 */

import cpp
import PointlessSelfComparison

from ComparisonOperation cmp
where pointlessSelfComparison(cmp) and not nanTest(cmp)
select cmp, "Self comparison."
