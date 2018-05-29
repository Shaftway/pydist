# pydist

pydist lets you take a Python script, possibly built out of a number of files in
a variety of folders, and builds a single file distributable script, which can
be executed directly.

## Usage

```bash
./pydist.sh --help
./pydist.sh [input file] [command or option]... [output file]
./pydist.sh [input file] [command or option]... --execute [argument]...
./pydist.sh [input file] [command or option]... --extract <path>
./pydist.sh [input file] [command or option]... --debug
```

- `[input file]`<br>
  The input file is optional. It takes an existing pydist script and uses it as
  a starting point, loading the files and options that were used to create that
  script. If this is not supplied a blank template is used with defaults for all
  of the options.

- `[command or option]`<br>
  Zero or more commands or options to alter the generated distributable. Each
  command or option may take arguments, see [Commands](#commands) and
  [Options](#options) for more details.

- `[output file]`<br>
  The file to write the distributable out to. This file will have permissions
  for the owner to execute it by default. If this is not supplied the generated
  distributable will be written to stdout.

- `--execute [argument]...`<br>
  Executes the generated distributable, without actually creating the final
  distributable. This can be used to test that you've included all of the files
  you may need.

- `--extract <path>`<br>
  Extracts the distributable's payload to `<path>` and writes out the command
  line that would be used to execute the Python script.

- `--debug`<br>
  Prints debugging information, including the generated folder structure, flags,
  expected command lines, etc.

## Output

If `[output file]` is provided the distributable script will be written to that
path. Otherwise the script will be written to stdout. This script can be
executed directly. Any arguments will be forwarded on to the Python script.

### Commands

Commands modify the files that get included in the distributable. They do this
by adding or removing files from a "staging" folder.

- `--add <root> <path> <pattern>`<br>
  Adds all files found in `<root>/<path>` that match the filename pattern
  `<pattern>`, relative to `<root>`. For example, if you use
  `--add ~/code/sample animals/monkey/* *.py` all of the `.py` files in
  `~/code/sample/animals/monkey/` will be added, but files that don't end in
  `.py` or files that are in a sub-folder of monkey will not be added. These
  files will be in the distributable in the `./animals/monkey/` folder.

- `--code <root> <path>`<br>
  Adds all `.py` files found in `<root>/<path>`, relative to `<root>`. This is
  analagous to `--add <root> <path> *.py`.

- `--data <root> <path>`<br>
  Adds all files found in `<root>/<path>`, relative to `<root>`. This is
  analagous to `--add <root> <path> *`.

- `--remove <path>`<br>
  Removes all files that match `<path>` from the distributable. This uses the
  distributable's folders, not any source folders.

### Options

All options begin with `--option`.

- `--option clean`<br>
  Indicates that options should not be written to the distributable. This makes
  a slightly smaller script, and can prevent leaking information in the options,
  but if this distributable is modified any of the options specified will be
  lost.

- `--option encoding <format>`<br>
  Specifies the format of the encoding used in the distributable. Valid values
  are `base64` (encoded using `base64`, decoded using `base64 --decode | openssl
  enc -base64 -d` - this supports OSX), `binary` (data is not encoded at all,
  injected into the script as binary data), `uuencode` (encoded using
  `uuencode`, decoded using `uudecode`), or `custom` (see below). The target
  system needs to be able to decode the data. Because of this, `binary` is the
  safest option (and therefore the default).

- `--option encoding custom <encoder> <decoder>`<br>
  Specifies a custom encoding used in the distributable. The staging folder is
  tar'd and gzip'd and piped into the encoder. The output of the encoder is then
  injected into the distributable script. When executed the staged data is
  extracted and piped into the decoder. The output of the decoder is un-gip'd
  and un-tar'd to recreated the staging folder.

- `--option main <path>`<br>
  Indicates the entry point for the Python script. If this is not supplied,
  Python expects a file called `__main__.py` in the root folder.

- `--option python <version>`<br>
  Specifies the version of Python that should be used to execute the script.
  Default is `python` (allowing the host system to select), but `python2` or
  `python3` can be specified to force Python 2.x or 3.x.

# Examples

For this example, let's assume we have the following directory structure:

```
~/pydist/demo/
├── images/
│   ├── organize.py
│   ├── mammals/
│   │   ├── anteater.png
│   │   └── primates/
│   │       └── monkey.png
│   └── spiders/
│       └── tarantulas/
│           └── big_scary_spider.png
└── life/
    ├── game_of_life.py
    └── mammals/
        ├── __init__.py
        ├── README.md
        ├── anteater.py
        └── primates/
            ├── human.py
            └── monkey.py
```

Let's build some distributables with this:

- `pydist.sh --code ~/pydist/demo/life . working-1.sh`<br>
  **Payload Structure:**
  ```
  ./
  ├── game_of_life.py
  └── mammals/
      ├── __init__.py
      ├── anteater.py
      └── primates/
          ├── human.py
          └── monkey.py
  ```
  **Command Line:** `python /tmp/tmp.1234/ ...`<br>
  This will cause an error when executed:
  ```
  /usr/bin/python: can't find '__main__' module in '/tmp/tmp.1234/'
  ```

- `pydist.sh working-1.sh --option main life/game_of_life.py working-2.sh`<br>
  **Payload Structure:** Unchanged<br>
  **Command Line:** `python /tmp/tmp.1235/life/game_of_life.py ...`<br>
  We've added the main script that should run. Now when we execute it doesn't
  fail right away, but we still need some images.

- `pydist.sh working-2.sh --add ~/pydist/demo images *.png working-3.sh`<br>
  **Payload Structure:**
  ```
  ./
  ├── game_of_life.py
  ├── images/
  │   ├── mammals/
  │   │   ├── anteater.png
  │   │   └── primates/
  │   │       └── monkey.png
  │   └── spiders/
  │       └── tarantulas/
  │           └── big_scary_spider.png
  └── mammals/
      ├── __init__.py
      ├── anteater.py
      └── primates/
          ├── human.py
          └── monkey.py
  ```
  **Command Line:** `python /tmp/tmp.1236/ ...`<br>
  Now we've got the images included. But, woah, we didn't mean to include
  `big_scary_spider.png`.

- `pydist.sh working-3.sh --remove images/spiders/ working-4.sh`<br>
  **Payload Structure:**
  ```
  ./
  ├── game_of_life.py
  ├── images/
  │   ├── mammals/
  │   │   ├── anteater.png
  │   │   └── primates/
  │   │       └── monkey.png
  │   └── spiders/
  │       └── tarantulas/
  │           └── big_scary_spider.png
  └── mammals/
      ├── __init__.py
      ├── anteater.py
      └── primates/
          ├── human.py
          └── monkey.py
  ```
  **Command Line:** `python /tmp/tmp.1237/ ...`<br>
  That's better, no big scary spider pictures. Time to test `life.sh`.

- `pydist.sh working-4.sh --option clean life.sh`
  **Payload Structure:** Unchanged<br>
  **Command Line:** `python /tmp/tmp.1236/ ...`<br>
  Now we just clean all of the options we used out of the distributable and ship
  `life.sh`.

Of course, all of these commands could be done in a single shot:

```bash
pydist.sh \
  --code ~/pydist/demo/life . \
  --add ~/pydist/demo images *.png \
  --remove images/spiders \
  --option main life/game_of_life.py \
  --option clean \
  life.sh;
```

# Cautions

The Python script will be executed from a randomly generated temp folder. Your
script will execute in the correct working directory, but should not rely on its
own location for reading or writing user files. It **should** rely on its own
location for reading its own data files. Relative imports will work as expected,
within the temp directory.

The temp folder will be deleted after the script executes. It can use this
folder as temporary space, but any files will be automatically deleted after
execution completes, so if you want to keep any data it should be stored
elsewhere.

# How does this whole thing work?

The distributable is just a bash script with the format:

```
#!/bin/bash
# <script to execute code>
exit;

OPTIONS:
option1=value1
option2=value2
<...>

PAYLOAD:
<compressed payload>
```

When the script is executed a temp directory is created and the payload is
uncompressed to it. The script then executes the uncompressed code using Python.
After execution the temp directory is deleted. The options are not used at run
time; they are only used when modifying an existing distributable.

When creating a distributable a temp directory is created. If an input file is
specified, the payload is extracted and decompressed into that temp directory
and the options are read out. Each command modifies the payload directory, and
when the distributable is ready to be written that payload directory is
compressed and injected into the script along with the options.
