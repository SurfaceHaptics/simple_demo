# cmake-common

This repository contains CMake scripts that have been copy-pasted between different Tanvas repositories.  It also embeds [cmake-conan](https://github.com/conan-io/cmake-conan/), a CMake script that invokes Conan commands from within a CMake build.

## Converting a project from `cmake-conan` to `cmake-common`

Make sure your project is up to date, with no local changes. From the root of the project, issue the following:
```
git subtree add --prefix=tools/cmake-common git@gitlab.tanvas.co:core-software/cmake-common.git master
```
This will pull down the latest `cmake-common` subtree (to use an explicit version, replace `master` with the desired version tag). If you see `prefix 'tools/cmake-common' already exists` then make sure the `cmake-common` directory is not present (it's OK for `tools` to be present, just not `cmake-common`).

Now delete the old `.gitmodules` file and the entire `tools/cmake-conan` directory.

In the root `CMakeLists.txt`, you can safely remove all of the copy-pasted stuff, basically everything after `project(blah)` to where sub-directories or files are added. All that stuff that was deleted can be replaced with:
```
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/tools/cmake-common" ${CMAKE_MODULE_PATH})
include(init-cpp)
```

## Updating cmake-conan

`cmake-conan` is included in this repository via `git-subtree`.  This results in a repository structure that doesn't require submodule commands: this is nice when using the repository's contents, but it does require special care when updating said repository.

To update `cmake-conan`, run

```
git subtree pull -P cmake-conan https://github.com/conan-io/cmake-conan develop  # or whatever branch you want to pull from
```

replacing `release/0.14` with whatever `cmake-conan` tip you want to update to (e.g. `master`, `develop`).  This will result in a merge commit between `cmake-conan` and `cmake-common` histories, which you can push to `cmake-common` as usual.

## Updating cmake-common from another project

If you make changes to `cmake-common` from a project that uses it and you wish to push those changes to `cmake-common`, use `git subtree push`:

```
git subtree push -P tools/cmake-common git@gitlab.tanvas.co:core-software/cmake-common.git master
```

replacing `master` with the `cmake-common` ref that you modified, and `tools/cmake-common` with the location of `cmake-common` in the consumer project.
