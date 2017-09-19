#!/bin/bash

set -e
set -o noclobber

declare -r  SOURCE_PATH='src'
declare -r  MAIN_SOURCE_PATH="$SOURCE_PATH/main"
declare -r  MAIN_JAVA_PATH="$MAIN_SOURCE_PATH/java"
declare -r  MAIN_C_PATH="$MAIN_SOURCE_PATH/c"
declare -r  PACKAGE_PREFIX='week_'
declare -r  QUESTION_PREFIX='Question_'
declare -r  QUESTION_DELIMITER='_'
declare -r  QUESTION_BASE_PATTERN='Question_\([[:digit:]]\+\)_\(.\+\)\.java'
declare -r  MANIFESTS_PATH='manifests'
declare -ra SUBMODULES=('https://github.com/Izzette/itec-2545-make-helpers.git')
declare -r  THIS_SCRIPT="itec-2545-convert-lab.sh"
declare -r  THIS_SCRIPT_URL="https://github.com/Izzette/itec-2545-convert-lab.git"

function get_week_number() { set -e
  sed 's|^'"$MAIN_JAVA_PATH/$PACKAGE_PREFIX"'\([[:digit:]]\+\).*$|\1|' \
    <(echo "$MAIN_JAVA_PATH/$PACKAGE_PREFIX"*)
}

function get_questions() { set -e
  declare package="$1"

  declare question_path="$MAIN_JAVA_PATH/$package"

  declare    question question_name
  declare -i question_number
  for question in "$question_path/$QUESTION_PREFIX"*.java; do
    {
      IFS= read -d $'\0' -r question_number
      IFS= read -d $'\0' -r question_name
      cat > /dev/null
    } < <(sed 's|^'"$question_path/$QUESTION_BASE_PATTERN"'$|\1\x00\2\x00|g' \
          <<< "$question")

    echo "$question_number $question_name"
  done | sort -n | cut -d ' ' -f 2-
}

function make_manifests_dir() { set -e
  mkdir -p "$MANIFESTS_PATH"
}

function create_manifests() { set -e
  declare    package="$1"
  declare -a questions=("${@:2}")

  declare    question_name
  declare -i question_number=1
  for question_name in "${questions[@]}"; do
    cat > "$MANIFESTS_PATH/$question_name.txt" <<EOF
Main-Class: $package.$QUESTION_PREFIX${question_number}$QUESTION_DELIMITER$question_name
EOF
    : $((question_number += 1))
  done
}

function add_manifests() { set -e
  git add manifests
}

function make_c_source_dir() { set -e
  mkdir -p "$MAIN_C_PATH"
}

function create_c_sources() { set -e
  declare    package="$1"
  declare -a questions=("${@:2}")

  declare    question_name
  declare -i question_number=1
  for question_name in "${questions[@]}"; do
    cat > "$MAIN_C_PATH/$question_name.c" <<EOF
// $question_name.c

#include <jni.h>

#include <$package/$QUESTION_PREFIX${question_number}$QUESTION_DELIMITER$question_name.h>

// vim: set ts=4 sw=4 noet syn=c:
EOF
    : $((question_number += 1))
  done
}

function add_c_sources() { set -e
  git add "$MAIN_C_PATH"
}

function create_makefile() { set -e
  declare -i week_number=$1
  declare -a questions=("${@:2}")

  declare question_name
  {
    cat <<EOF
# Makefile

WEEK_NUMBER := $week_number
EOF

    echo -n 'QUESTIONS :='
    for question_name in "${questions[@]}"; do
      # shellcheck disable=SC1003
      echo     ' \'
      echo -ne '\t'
      echo -n  "$question_name"
    done
    echo

    cat <<EOF

# This provides our default target.
include itec-2545-make-helpers/Makefile.itec-2545

# vim: set ts=4 sw=4 noet syn=make:
EOF
  } > Makefile
}

function add_makefile() { set -e
  git add Makefile
}

function get_iml() { set -e
  declare imls=(Java\ Auto\ Grader*.iml)
  echo "${imls[0]}"
}

function generate_iml_patch() { set -e
  declare    iml="$1"
  declare -a questions=("${@:2}")

  cat <<EOF
--- a/$iml$(echo -ne '\t')
+++ b/$iml$(echo -ne '\t')
@@ -1,6 +1,6 @@
 <?xml version="1.0" encoding="UTF-8"?>
 <module org.jetbrains.idea.maven.project.MavenProjectsManager.isMavenModule="true" type="JAVA_MODULE" version="4">
-  <component name="NewModuleRootManager" LANGUAGE_LEVEL="JDK_1_8" inherit-compiler-output="false">
+  <component name="NewModuleRootManager" LANGUAGE_LEVEL="JDK_1_8">
     <output url="file://\$MODULE_DIR\$/target/classes" />
     <output-test url="file://\$MODULE_DIR\$/target/test-classes" />
     <content url="file://\$MODULE_DIR\$">
EOF

  cat <<EOF
@@ -10,8 +10,$((8 + 9 * ($# - 1) - 1)) @@
       <excludeFolder url="file://\$MODULE_DIR\$/target" />
     </content>
     <orderEntry type="inheritedJdk" />
EOF

  declare question_name
  for question_name in "${questions[@]}"; do
    cat <<EOF
+    <orderEntry type="module-library">
+      <library>
+        <CLASSES>
+          <root url="jar://\$MODULE_DIR\$/out/jars/$question_name.jar!/" />
+        </CLASSES>
+        <JAVADOC />
+        <SOURCES />
+      </library>
+    </orderEntry>
EOF
  done

  cat <<EOF
     <orderEntry type="sourceFolder" forTests="false" />
-    <orderEntry type="library" name="Maven: edu.minneapolis:input-utils:1.0.1" level="project" />
     <orderEntry type="library" scope="TEST" name="Maven: junit:junit:4.12" level="project" />
     <orderEntry type="library" scope="TEST" name="Maven: org.hamcrest:hamcrest-core:1.3" level="project" />
     <orderEntry type="library" name="Maven: com.google.guava:guava:22.0" level="project" />
EOF
}

function patch_iml() { set -e
  declare    iml="$1"
  declare -a questions=("${@:2}")

  patch -Np1 < <(generate_iml_patch "$iml" "${questions[@]}")
}

function rename_iml() { set -e
  declare iml="$1"
  declare new_iml='Java_Auto_Grader.iml'

  mv "$iml" "$new_iml"
  echo "$new_iml"
}

function add_iml() { set -e
  declare iml="$1"
  git add "$iml"
}

function create_gitignore() { set -e
  rm -f .gitignore
  cat > .gitignore <<EOF
# .gitignore

# Excluded directories
out
target
.idea

# Excluded files
*.iml
!Java Auto Grader*.iml
*.o
.*.sw*
.*.bak

# vim: set syn=conf:
EOF
}

function add_gitignore() { set -e
  git add .gitignore
}

function remove_idea() { set -e
  git rm -r .idea
}

function add_submodules() { set -e
  declare submodule
  for submodule in "${SUBMODULES[@]}"; do
    git submodule add --force "$submodule";
  done

  git submodule update --init --recursive
}

function convert() { set -e
  if [[ 1 -eq $# ]]; then
    cd "$1"
  fi

  declare week_number
  week_number="$(get_week_number)"

  declare package="$PACKAGE_PREFIX$week_number"

  declare -a questions=()
  declare question_name
  while IFS= read -r question_name; do
    questions+=("$question_name")
  done < <(get_questions "$package")

  declare iml new_iml
  iml="$(get_iml)"

  make_manifests_dir
  create_manifests "$package" "${questions[@]}"
  add_manifests

  make_c_source_dir
  create_c_sources "$package" "${questions[@]}"
  add_c_sources

  create_makefile "$week_number" "${questions[@]}"
  add_makefile

  patch_iml "$iml" "${questions[@]}"
  new_iml="$(rename_iml "$iml")" && iml="$new_iml"
  add_iml "$iml"

  create_gitignore
  add_gitignore

  remove_idea
  add_submodules
}

function commit() { set -e
  if [[ 1 -eq $# ]]; then
    cd "$1"
  fi

  git commit -at <(cat <<EOF
Automatically migrated by $THIS_SCRIPT

* Generated JAR manifests for JAR applications.
* Created C source files for JNI usage.
* Created Makefile for GNU Make build system.
* Patched auto grader "iml" to include project JARs in classpath.
* Created standard ITEC-2545 lab gitignore.
* Removed non-source .idea IDE specific configuration.
* Added helper submodules ${SUBMODULES[*]}.
* Learn more about $THIS_SCRIPT at <$THIS_SCRIPT_URL>.
EOF
  )
}

function usage() { set -e
  declare progname="$1"

  echo "Usage: $progname convert [<path/to/cloned/repo>]"
  echo "       $progname commit [<path/to/cloned/repo>]"
  echo "       $progname <-h|--help|help>"
}

case "$1" in
  convert)
    if [[ 1 -gt $# || 2 -lt $# ]]; then
      usage "$0"
      exit 1
    fi

    convert ${2:+"$2"}
    ;;
  commit)
    if [[ 1 -gt $# || 2 -lt $# ]]; then
      usage "$0"
      exit 1
    fi

    commit ${2:+"$2"}
    ;;
  -h|--help|help)
    usage "$0"
    ;;
  include)
    ;;
  *)
    usage "$0"
    exit 1
    ;;
esac

# vim: set ts=2 sw=2 et syn=sh ft=sh:
