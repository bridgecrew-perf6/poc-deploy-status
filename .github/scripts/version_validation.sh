#!/bin/bash

echo "---> Checking CHANGELOG.md for $GITHUB_REPOSITORY"

# verify CHANGELOG.md exists
echo "---> Checking for CHANGELOG.md"
if [[ ! -f "CHANGELOG.md"  ]]
then
    echo "::error::CHANGELOG file NOT FOUND"
    exit 1
fi

check_format(){
  echo "---> Checking for properly formatted version in CHANGELOG.md"
  if [[ -z "${version_num}"  ]]; then
      echo "::error::There is no version number in CHANGELOG.md, weird."
      exit 1
  fi
}

if [ "$GITHUB_EVENT_NAME" = "workflow_dispatch" ] && [ "${REPO_TAG}" != "" ]; then
  version_num=$(echo ${REPO_TAG} | grep -Eo [0-9].*[0-9]*.[0-9]*)
  check_format
else
  # verify CHANGELOG.md has a version that has been updated
  version_line=$(echo "$( git show :CHANGELOG.md)" | egrep -o '^+# [0-9].*[0-9]*.[0-9]*' | head -1 ) || true
  if [[ -z "${version_line}"  ]]; then
      echo "::error::CHANGELOG.md must have an updated version number. Git diff didn't show changes"
      echo "::dump::Event name: $GITHUB_EVENT_NAME, and Ref: $GITHUB_REF"
      exit 1
  fi

  version_line_old=$(head -20 CHANGELOG.md | grep -Eo -m 2 "# [0-9].*[0-9]*.[0-9]*" | awk 'FNR == 2 {print $2}')
  if [[ -z "${version_line_old}"  ]]; then
      echo "::error::There is no old version number in CHANGELOG.md, weird."
      exit 1
  fi

  version_num=$(echo ${version_line} | grep -Eo [0-9].*[0-9]*.[0-9]*)
  check_format

  # check that the version number was actually increased
  echo "---> Checking that the version number was incremented"

  # split new version into an array
  IFS='.' eval 'new_version_split=($version_num)'

  # split old version into an array
  old_version_num=$(echo ${version_line_old} | grep -Eo [0-9].*[0-9]*.[0-9]*)
  IFS='.' eval 'old_version_split=($old_version_num)'

  # check major
  if [[ ${new_version_split[0]} -eq ${old_version_split[0]} ]];then
    # check minor
    if [[ ${new_version_split[1]} -eq ${old_version_split[1]} ]];then
      # check patch
      if [[ ${new_version_split[2]} -eq ${old_version_split[2]} ]];then
        echo "::error::CHANGELOG.md version must be incremented. Main version: $old_version_num, $GITHUB_REF version: $version_num"
        exit 1
      elif [[ ${new_version_split[2]} -lt ${old_version_split[2]} ]];then
        echo "::error::CHANGELOG.md version must be incremented. Main version: $old_version_num, $GITHUB_REF version: $version_num"
        exit 1
      fi
    elif [[ ${new_version_split[1]} -lt ${old_version_split[1]} ]];then
      echo "::error::CHANGELOG.md version must be incremented. Main version: $old_version_num, $GITHUB_REF version: $version_num"
      exit 1
    fi
    # output version
    echo "::set-output name=new_version::$version_num" 
    echo "::notice::Version: $version_num"
  elif [[ ${new_version_split[0]} -lt ${old_version_split[0]} ]];then
    echo "::error::CHANGELOG.md version must be incremented. Main version: $old_version_num, $GITHUB_REF version: $version_num"
    exit 1
  fi
fi

MSG="Using manual run. User ${GITHUB_ACTOR} manually triggered the workflow"
echo "::notice::$MSG. Version: $version_num"
echo "::set-output name=new_version::$version_num"
