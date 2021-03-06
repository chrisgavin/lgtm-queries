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

import python
import semmle.python.dependencies.Dependencies
import semmle.python.dependencies.DependencyKind

/** Combine the source-file and package into a single string:
 * /path/to/file.py<|>package-name-and-version
 */
string munge(File sourceFile, ExternalPackage package) {
    result = "/" + sourceFile.getRelativePath() + "<|>" + package.getName() + "<|>" + package.getVersion() or
    not exists(package.getVersion()) and result = "/" + sourceFile.getRelativePath() + "<|>" + package.getName() + "<|>unknown"
}

abstract class ExternalPackage extends Object {

    ExternalPackage() {
        this instanceof ModuleObject
    }

    abstract string getName();

    abstract string getVersion();

    Object getAttribute(string name) {
        result = this.(ModuleObject).getAttribute(name)
    }

    PackageObject getPackage() {
        result = this.(ModuleObject).getPackage()
    }

}

bindingset[text]
private predicate is_version(string text) {
    text.regexpMatch("\\d+\\.\\d+(\\.\\d+)?([ab]\\d+)?")
}


class DistPackage extends ExternalPackage {

    DistPackage() {
        exists(string path |
            path = this.(ModuleObject).getModule().getPath().getName() |
            path.regexpMatch(".*/dist-packages/[^/]+")
            or
            path.regexpMatch(".*/site-packages/[^/]+")
        )
    }

    /* We don't extract the meta-data for dependencies (yet), so make a best guess from the source
     * https://www.python.org/dev/peps/pep-0396/ 
     */
    private predicate possibleVersion(string version, int priority) {
        version = this.getAttribute("__version__").(StringObject).getText() and
        is_version(version) and priority = 3
        or
        exists(SequenceObject tuple, NumericObject major, NumericObject minor, string base_version |
            this.getAttribute("version_info") = tuple and
            major = tuple.getInferredElement(0) and minor = tuple.getInferredElement(1) and
            base_version = major.intValue() + "." + minor.intValue() |
            version = base_version + "." + tuple.getBuiltinElement(2).(NumericObject).intValue()
            or
            not exists(tuple.getBuiltinElement(2)) and version = base_version
        ) and priority = 2
        or
        exists(string v |
            v.toLowerCase() = "version" |
            is_version(version) and
            version = this.getAttribute(v).(StringObject).getText()
        ) and priority = 1
    }

    string getVersion() {
        this.possibleVersion(result, max(int priority | this.possibleVersion(_, priority)))
    }

    string getName() {
        result = this.(ModuleObject).getShortName()
    }

    predicate fromSource(Object src) {
        exists(ModuleObject m |
            m.getModule() = src.(ControlFlowNode).getEnclosingModule() or
            src = m |
            m = this or
            m.getPackage+() = this and
            not exists(DistPackage inter |
                m.getPackage*() = inter and
                inter.getPackage+() = this
            )
        )
    }

}

predicate dependency(AstNode src, DistPackage package) {
    exists(DependencyKind cat, Object target |
        cat.isADependency(src, target) |
        package.fromSource(target)
    )
}
