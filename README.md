# rpm build wrapper

This is a bash script that can be downloaded and used in `rpmbuild` source folders
to help build the RPM inside an applicable docker container.

## Usage

```bash
# build with rocky 8
./build.sh 8
# build with rocky 9
./build.sh 9
```

Run directly from the official site:

```bash
/bin/bash -c "$(curl -fsSL https://yum.jc21.com/build.sh)" -- 9
```

Building with language specific docker images

See [one of the rpmbuild image tags](https://hub.docker.com/r/jc21/rpmbuild-rocky9/tags) for possible options.

```bash
./build.sh 9 golang
./build.sh 9 rust
./build.sh 9 haskell
```
