module [
    Path,
    ReadErr,
    WriteErr,
    DirEntry,
    DirErr,
    MetadataErr,
    # PathComponent,
    # CanonicalizeErr,
    # WindowsRoot,
    # toComponents,
    # walkComponents,
    display,
    fromStr,
    fromBytes,
    withExtension,
    # These can all be found in File as well
    isDir,
    isFile,
    isSymLink,
    type,
    writeUtf8,
    writeBytes,
    write,
    readUtf8,
    readBytes,
    # read, TODO fix "Ability specialization is unknown - code generation cannot proceed!: DeriveError(UnboundVar)"
    delete,
    # These can all be found in Dir as well
    listDir,
    createDir,
    createAll,
    deleteEmpty,
    deleteAll,
]

import InternalPath
import InternalFile
import FileMetadata exposing [FileMetadata]
import PlatformTasks

## An error when reading a path's file metadata from disk.
MetadataErr : InternalPath.GetMetadataErr

# You can canonicalize a [Path] using `Path.canonicalize`.
#
# Comparing canonical paths is often more reliable than comparing raw ones.
# For example, `Path.fromStr "foo/bar/../baz" == Path.fromStr "foo/baz"` will return [Bool.false],
# because those are different paths even though their canonical equivalents would be equal.
#
# Also note that canonicalization reads from the file system (in order to resolve symbolic
# links, and to convert relative paths into absolute ones). This means that it is not only
# a [Task](../Task#Task) (which can fail), but also that running `canonicalize` on the same [Path] twice
# may give different answers. An example of a way this could happen is if a symbolic link
# in the path changed on disk to point somewhere else in between the two `canonicalize` calls.
#
# Similarly, remember that canonical paths are not guaranteed to refer to a valid file. They
# might have referred to one when they were canonicalized, but that file may have moved or
# been deleted since the canonical path was created. So you might canonicalize a [Path],
# and then immediately use that [Path] to read a file from disk, and still get back an error
# because something relevant changed on the filesystem between the two operations.
#
# Also note that different filesystems have different rules for syntactically valid paths.
# Suppose you're on a machine with two disks, one formatted as ext4 and another as FAT32.
# It's possible to list the contents of a directory on the ext4 disk, and get a `CanPath` which
# is valid on that disk, but invalid on the other disk. One way this could happen is if the
# directory on the ext4 disk has a filename containing a `:` in it. `:` is allowed in ext4
# paths but is considered invalid in FAT32 paths.

## Represents a path to a file or directory on the filesystem.
Path : InternalPath.InternalPath

## Record which represents a directory
##
## > This is the same as [`Dir.DirEntry`](Dir#DirEntry).
DirEntry : {
    path : Path,
    type : [File, Dir, Symlink],
    metadata : FileMetadata,
}

## Tag union of possible errors when reading a file or directory.
##
## > This is the same as [`File.ReadErr`](File#ReadErr).
ReadErr : InternalFile.ReadErr

## Tag union of possible errors when writing a file or directory.
##
## > This is the same as [`File.WriteErr`](File#WriteErr).
WriteErr : InternalFile.WriteErr

## **NotFound** - This error is raised when the specified directory does not exist, typically during attempts to access or manipulate it.
##
## **PermissionDenied** - Occurs when the user lacks the necessary permissions to perform an action on a directory, such as reading, writing, or executing.
##
## **AlreadyExists** - This error is thrown when trying to create a directory that already exists.
##
## **NotADirectory** - Raised when an operation that requires a directory (e.g., listing contents) is attempted on a file instead.
##
## **Other** - A catch-all for any other types of errors not explicitly listed above.
##
## > This is the same as [`Dir.Err`](Dir#Err).
DirErr : [
    NotFound,
    PermissionDenied,
    AlreadyExists,
    NotADirectory,
    Other Str,
]

## Write data to a file.
##
## First encode a `val` using a given `fmt` which implements the ability [Encode.EncoderFormatting](https://www.roc-lang.org/builtins/Encode#EncoderFormatting).
##
## For example, suppose you have a `Json.toCompactUtf8` which implements
## [Encode.EncoderFormatting](https://www.roc-lang.org/builtins/Encode#EncoderFormatting).
## You can use this to write [JSON](https://en.wikipedia.org/wiki/JSON)
## data to a file like this:
##
## ```
## # Writes `{"some":"json stuff"}` to the file `output.json`:
## Path.write
##     { some: "json stuff" }
##     (Path.fromStr "output.json")
##     Json.toCompactUtf8
## ```
##
## This opens the file first and closes it after writing to it.
## If writing to the file fails, for example because of a file permissions issue, the task fails with [WriteErr].
##
## > To write unformatted bytes to a file, you can use [Path.writeBytes] instead.
write : val, Path, fmt -> Task {} [FileWriteErr Path WriteErr] where val implements Encoding, fmt implements EncoderFormatting
write = \val, path, fmt ->
    bytes = Encode.toBytes val fmt

    # TODO handle encoding errors here, once they exist
    writeBytes bytes path

## Writes bytes to a file.
##
## ```
## # Writes the bytes 1, 2, 3 to the file `myfile.dat`.
## Path.writeBytes [1, 2, 3] (Path.fromStr "myfile.dat")
## ```
##
## This opens the file first and closes it after writing to it.
##
## > To format data before writing it to a file, you can use [Path.write] instead.
writeBytes : List U8, Path -> Task {} [FileWriteErr Path WriteErr]
writeBytes = \bytes, path ->
    pathBytes = InternalPath.toBytes path
    PlatformTasks.fileWriteBytes pathBytes bytes
    |> Task.mapErr \err -> FileWriteErr path (InternalFile.handleWriteErr err)

## Writes a [Str] to a file, encoded as [UTF-8](https://en.wikipedia.org/wiki/UTF-8).
##
## ```
## # Writes "Hello!" encoded as UTF-8 to the file `myfile.txt`.
## Path.writeUtf8 "Hello!" (Path.fromStr "myfile.txt")
## ```
##
## This opens the file first and closes it after writing to it.
##
## > To write unformatted bytes to a file, you can use [Path.writeBytes] instead.
writeUtf8 : Str, Path -> Task {} [FileWriteErr Path WriteErr]
writeUtf8 = \str, path ->
    pathBytes = InternalPath.toBytes path
    PlatformTasks.fileWriteUtf8 pathBytes str
    |> Task.mapErr \err -> FileWriteErr path (InternalFile.handleWriteErr err)

## Represents an error that can happen when canonicalizing a path.
# CanonicalizeErr a : [
#    PathCanonicalizeErr {},
# ]a

## Note that the path may not be valid depending on the filesystem where it is used.
## For example, paths containing `:` are valid on ext4 and NTFS filesystems, but not
## on FAT ones. So if you have multiple disks on the same machine, but they have
## different filesystems, then this path could be valid on one but invalid on another!
##
## It's safest to assume paths are invalid (even syntactically) until given to an operation
## which uses them to open a file. If that operation succeeds, then the path was valid
## (at the time). Otherwise, error handling can happen for that operation rather than validating
## up front for a false sense of security (given symlinks, parts of a path being renamed, etc.).
fromStr : Str -> Path
fromStr = \str ->
    FromStr str
    |> InternalPath.wrap

## Not all filesystems use Unicode paths. This function can be used to create a path which
## is not valid Unicode (like a [Str] is), but which is valid for a particular filesystem.
##
## Note that if the list contains any `0` bytes, sending this path to any file operations
## (e.g. `Path.readBytes` or `WriteStream.openPath`) will fail.
fromBytes : List U8 -> Path
fromBytes = \bytes ->
    ArbitraryBytes bytes
    |> InternalPath.wrap

# Note that canonicalization reads from the file system (in order to resolve symbolic
# links, and to convert relative paths into absolute ones). This means that it is not only
# a [Task] (which can fail), but also that running [canonicalize] on the same [Path] twice
# may give different answers. An example of a way this could happen is if a symbolic link
# in the path changed on disk to point somewhere else in between the two [canonicalize] calls.
#
# Returns an effect type of `[Metadata, Cwd]` because it can resolve symbolic links
# and can access the current working directory by turning a relative path into an
# absolute one (which can prepend the absolute path of the current working directory to
# the relative path).
# canonicalize : Path -> Task Path (CanonicalizeErr *) [Metadata, Read [Env]]*
## Unfortunately, operating system paths do not include information about which charset
## they were originally encoded with. It's most common (but not guaranteed) that they will
## have been encoded with the same charset as the operating system's curent locale (which
## typically does not change after it is set during installation of the OS), so
## this should convert a [Path] to a valid string as long as the path was created
## with the given `Charset`. (Use `Env.charset` to get the current system charset.)
##
## For a conversion to [Str] that is lossy but does not return a [Result], see
## [display].
## toInner : Path -> [Str Str, Bytes (List U8)]
## Assumes a path is encoded as [UTF-8](https://en.wikipedia.org/wiki/UTF-8),
## and converts it to a string using `Str.display`.
##
## This conversion is lossy because the path may contain invalid UTF-8 bytes. If that happens,
## any invalid bytes will be replaced with the [Unicode replacement character](https://unicode.org/glossary/#replacement_character)
## instead of returning an error. As such, it's rarely a good idea to use the [Str] returned
## by this function for any purpose other than displaying it to a user.
##
## When you don't know for sure what a path's encoding is, UTF-8 is a popular guess because
## it's the default on UNIX and also is the encoding used in Roc strings. This platform also
## automatically runs applications under the [UTF-8 code page](https://docs.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page)
## on Windows.
##
## Converting paths to strings can be an unreliable operation, because operating systems
## don't record the paths' encodings. This means it's possible for the path to have been
## encoded with a different character set than UTF-8 even if UTF-8 is the system default,
## which means when [display] converts them to a string, the string may include gibberish.
## [Here is an example.](https://unix.stackexchange.com/questions/667652/can-a-file-path-be-invalid-utf-8/667863#667863)
##
## If you happen to know the `Charset` that was used to encode the path, you can use
## `toStrUsingCharset` instead of [display].
display : Path -> Str
display = \path ->
    when InternalPath.unwrap path is
        FromStr str -> str
        FromOperatingSystem bytes | ArbitraryBytes bytes ->
            when Str.fromUtf8 bytes is
                Ok str -> str
                # TODO: this should use the builtin Str.display to display invalid UTF-8 chars in just the right spots, but that does not exist yet!
                Err _ -> "�"

# isEq : Path, Path -> Bool
# isEq = \p1, p2 ->
#     when InternalPath.unwrap p1 is
#         FromOperatingSystem bytes1 | ArbitraryBytes bytes1 ->
#             when InternalPath.unwrap p2 is
#                 FromOperatingSystem bytes2 | ArbitraryBytes bytes2 -> bytes1 == bytes2
#                 # We can't know the encoding that was originally used in the path, so we convert
#                 # the string to bytes and see if those bytes are equal to the path's bytes.
#                 #
#                 # This may sound unreliable, but it's how all paths are compared; since the OS
#                 # doesn't record which encoding was used to encode the path name, the only
#                 # reasonable# definition for path equality is byte-for-byte equality.
#                 FromStr str2 -> Str.isEqUtf8 str2 bytes1
#         FromStr str1 ->
#             when InternalPath.unwrap p2 is
#                 FromOperatingSystem bytes2 | ArbitraryBytes bytes2 -> Str.isEqUtf8 str1 bytes2
#                 FromStr str2 -> str1 == str2
# compare : Path, Path -> [Lt, Eq, Gt]
# compare = \p1, p2 ->
#     when InternalPath.unwrap p1 is
#         FromOperatingSystem bytes1 | ArbitraryBytes bytes1 ->
#             when InternalPath.unwrap p2 is
#                 FromOperatingSystem bytes2 | ArbitraryBytes bytes2 -> Ord.compare bytes1 bytes2
#                 FromStr str2 -> Str.compareUtf8 str2 bytes1 |> Ord.reverse
#         FromStr str1 ->
#             when InternalPath.unwrap p2 is
#                 FromOperatingSystem bytes2 | ArbitraryBytes bytes2 -> Str.compareUtf8 str1 bytes2
#                 FromStr str2 -> Ord.compare str1 str2

## Represents a attributes of a path such as a parent directory, the current
## directory for use when transforming a path.
# PathComponent : [
#    ParentDir, # e.g. ".." on UNIX or Windows
#    CurrentDir, # e.g. "." on UNIX
#    Named Str, # e.g. "stuff" on UNIX
#    DirSep Str, # e.g. "/" on UNIX, "\" or "/" on Windows. Or, sometimes, "¥" on Windows - see
#    # https://docs.microsoft.com/en-us/windows/win32/intl/character-sets-used-in-file-names
#    #
#    # This is included as an option so if you're transforming part of a path,
#    # you can write back whatever separator was originally used.
# ]

# Note that a root of Slash (`/`) has different meanings on UNIX and on Windows.
# * On UNIX, `/` at the beginning of the path refers to the filesystem root, and means the path is absolute.
# * On Windows, `/` at the beginning of the path refers to the current disk drive, and means the path is relative.
# PathRoot : [
#     WindowsSpecificRoot WindowsRoot, # e.g. "C:" on Windows
#     Slash,
#     None,
# ]
# TODO see https://doc.rust-lang.org/std/path/enum.Prefix.html
## Represents the root path on Windows operating system, which refers to the
## current disk drive.
# WindowsRoot : []

## Returns the root of the path.
# root : Path -> PathRoot
# components : Path -> { root : PathRoot, components : List PathComponent }
## Walk over the path's [components].
# walk :
#     Path,
#     # None means it's a relative path
#     (PathRoot -> state),
#     (state, PathComponent -> state)
#     -> state
## Returns the path without its last [`component`](#components).
##
## If the path was empty or contained only a [root](#PathRoot), returns the original path.
# dropLast : Path -> Path
# TODO see https://doc.rust-lang.org/std/path/struct.Path.html#method.join for
# the definition of the term "adjoin" - should we use that term?
# append : Path, Path -> Path
# append = \prefix, suffix ->
#     content =
#         when InternalPath.unwrap prefix is
#             FromOperatingSystem prefixBytes ->
#                 when InternalPath.unwrap suffix is
#                     FromOperatingSystem suffixBytes ->
#                         # Neither prefix nor suffix had interior nuls, so the answer won't either
#                         List.concat prefixBytes suffixBytes
#                         |> FromOperatingSystem
#                     ArbitraryBytes suffixBytes ->
#                         List.concat prefixBytes suffixBytes
#                         |> ArbitraryBytes
#                     FromStr suffixStr ->
#                         # Append suffixStr by writing it to the end of prefixBytes
#                         Str.appendToUtf8 suffixStr prefixBytes (List.len prefixBytes)
#                         |> ArbitraryBytes
#             ArbitraryBytes prefixBytes ->
#                 when InternalPath.unwrap suffix is
#                     ArbitraryBytes suffixBytes | FromOperatingSystem suffixBytes ->
#                         List.concat prefixBytes suffixBytes
#                         |> ArbitraryBytes
#                     FromStr suffixStr ->
#                         # Append suffixStr by writing it to the end of prefixBytes
#                         Str.writeUtf8 suffixStr prefixBytes (List.len prefixBytes)
#                         |> ArbitraryBytes
#             FromStr prefixStr ->
#                 when InternalPath.unwrap suffix is
#                     ArbitraryBytes suffixBytes | FromOperatingSystem suffixBytes ->
#                         List.concat suffixBytes (Str.toUtf8 prefixStr)
#                         |> ArbitraryBytes
#                     FromStr suffixStr ->
#                         Str.concat prefixStr suffixStr
#                         |> FromStr
#     InternalPath.wrap content
# appendStr : Path, Str -> Path
# appendStr = \prefix, suffixStr ->
#     content =
#         when InternalPath.unwrap prefix is
#             FromOperatingSystem prefixBytes | ArbitraryBytes prefixBytes ->
#                 # Append suffixStr by writing it to the end of prefixBytes
#                 Str.writeUtf8 suffixStr prefixBytes (List.len prefixBytes)
#                 |> ArbitraryBytes
#             FromStr prefixStr ->
#                 Str.concat prefixStr suffixStr
#                 |> FromStr
#     InternalPath.wrap content
## Returns [Bool.true] if the first path begins with the second.
# startsWith : Path, Path -> Bool
# startsWith = \path, prefix ->
#     when InternalPath.unwrap path is
#         FromOperatingSystem pathBytes | ArbitraryBytes pathBytes ->
#             when InternalPath.unwrap prefix is
#                 FromOperatingSystem prefixBytes | ArbitraryBytes prefixBytes ->
#                     List.startsWith pathBytes prefixBytes
#                 FromStr prefixStr ->
#                     strLen = Str.countUtf8Bytes prefixStr
#                     if strLen == List.len pathBytes then
#                         # Grab the first N bytes of the list, where N = byte length of string.
#                         bytesPrefix = List.takeAt pathBytes 0 strLen
#                         # Compare the two for equality.
#                         Str.isEqUtf8 prefixStr bytesPrefix
#                     else
#                         Bool.false
#         FromStr pathStr ->
#             when InternalPath.unwrap prefix is
#                 FromOperatingSystem prefixBytes | ArbitraryBytes prefixBytes ->
#                     Str.startsWithUtf8 pathStr prefixBytes
#                 FromStr prefixStr ->
#                     Str.startsWith pathStr prefixStr
## Returns [Bool.true] if the first path ends with the second.
# endsWith : Path, Path -> Bool
# endsWith = \path, prefix ->
#     when InternalPath.unwrap path is
#         FromOperatingSystem pathBytes | ArbitraryBytes pathBytes ->
#             when InternalPath.unwrap suffix is
#                 FromOperatingSystem suffixBytes | ArbitraryBytes suffixBytes ->
#                     List.endsWith pathBytes suffixBytes
#                 FromStr suffixStr ->
#                     strLen = Str.countUtf8Bytes suffixStr
#                     if strLen == List.len pathBytes then
#                         # Grab the last N bytes of the list, where N = byte length of string.
#                         bytesSuffix = List.takeAt pathBytes (strLen - 1) strLen
#                         # Compare the two for equality.
#                         Str.startsWithUtf8 suffixStr bytesSuffix
#                     else
#                         Bool.false
#         FromStr pathStr ->
#             when InternalPath.unwrap suffix is
#                 FromOperatingSystem suffixBytes | ArbitraryBytes suffixBytes ->
#                     Str.endsWithUtf8 pathStr suffixBytes
#                 FromStr suffixStr ->
#                     Str.endsWith pathStr suffixStr
# TODO https://doc.rust-lang.org/std/path/struct.Path.html#method.strip_prefix
# TODO idea: what if it's Path.openRead and Path.openWrite? And then e.g. Path.metadata,
# Path.isDir, etc.

## Returns true if the path exists on disk and is pointing at a directory.
## Returns `Task.ok false` if the path exists and it is not a directory. If the path does not exist,
## this function will return `Task.err PathErr PathDoesNotExist`.
##
## This uses [rust's std::path::is_dir](https://doc.rust-lang.org/std/path/struct.Path.html#method.is_dir).
##
## > [`File.isDir`](File#isDir) does the same thing, except it takes a [Str] instead of a [Path].
isDir : Path -> Task Bool [PathErr MetadataErr]
isDir = \path ->
    res = type! path
    Task.ok (res == IsDir)

## Returns true if the path exists on disk and is pointing at a regular file.
## Returns `Task.ok false` if the path exists and it is not a file. If the path does not exist,
## this function will return `Task.err PathErr PathDoesNotExist`.
##
## This uses [rust's std::path::is_file](https://doc.rust-lang.org/std/path/struct.Path.html#method.is_file).
##
## > [`File.isFile`](File#isFile) does the same thing, except it takes a [Str] instead of a [Path].
isFile : Path -> Task Bool [PathErr MetadataErr]
isFile = \path ->
    res = type! path
    Task.ok (res == IsFile)

## Returns true if the path exists on disk and is pointing at a symbolic link.
## Returns `Task.ok false` if the path exists and it is not a symbolic link. If the path does not exist,
## this function will return `Task.err PathErr PathDoesNotExist`.
##
## This uses [rust's std::path::is_symlink](https://doc.rust-lang.org/std/path/struct.Path.html#method.is_symlink).
##
## > [`File.isSymLink`](File#isSymLink) does the same thing, except it takes a [Str] instead of a [Path].
isSymLink : Path -> Task Bool [PathErr MetadataErr]
isSymLink = \path ->
    res = type! path
    Task.ok (res == IsSymLink)

## Return the type of the path if the path exists on disk.
##
## > [`File.type`](File#type) does the same thing, except it takes a [Str] instead of a [Path].
type : Path -> Task [IsFile, IsDir, IsSymLink] [PathErr MetadataErr]
type = \path ->
    InternalPath.toBytes path
    |> PlatformTasks.pathType
    |> Task.mapErr \err -> PathErr (InternalPath.handlerGetMetadataErr err)
    |> Task.map \pathType ->
        if pathType.isSymLink then
            IsSymLink
        else if pathType.isDir then
            IsDir
        else
            IsFile

## If the last component of this path has no `.`, appends `.` followed by the given string.
## Otherwise, replaces everything after the last `.` with the given string.
##
## ```
## # Each of these gives "foo/bar/baz.txt"
## Path.fromStr "foo/bar/baz" |> Path.withExtension "txt"
## Path.fromStr "foo/bar/baz." |> Path.withExtension "txt"
## Path.fromStr "foo/bar/baz.xz" |> Path.withExtension "txt"
## ```
withExtension : Path, Str -> Path
withExtension = \path, extension ->
    when InternalPath.unwrap path is
        FromOperatingSystem bytes | ArbitraryBytes bytes ->
            beforeDot =
                when List.splitLast bytes (Num.toU8 '.') is
                    Ok { before } -> before
                    Err NotFound -> bytes

            beforeDot
            |> List.reserve (Str.countUtf8Bytes extension |> Num.intCast |> Num.addSaturated 1)
            |> List.append (Num.toU8 '.')
            |> List.concat (Str.toUtf8 extension)
            |> ArbitraryBytes
            |> InternalPath.wrap

        FromStr str ->
            beforeDot =
                when Str.splitLast str "." is
                    Ok { before } -> before
                    Err NotFound -> str

            beforeDot
            |> Str.reserve (Str.countUtf8Bytes extension |> Num.addSaturated 1)
            |> Str.concat "."
            |> Str.concat extension
            |> FromStr
            |> InternalPath.wrap

# NOTE: no withExtensionBytes because it's too narrow. If you really need to get some
# non-Unicode in there, do it with Path.fromBytes.

## Deletes a file from the filesystem.
##
## Performs a [`DeleteFile`](https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-deletefile)
## on Windows and [`unlink`](https://en.wikipedia.org/wiki/Unlink_(Unix)) on
## UNIX systems. On Windows, this will fail when attempting to delete a readonly
## file; the file's readonly permission must be disabled before it can be
## successfully deleted.
##
## ```
## # Deletes the file named
## Path.delete (Path.fromStr "myfile.dat") [1, 2, 3]
## ```
##
## > This does not securely erase the file's contents from disk; instead, the operating
## system marks the space it was occupying as safe to write over in the future. Also, the operating
## system may not immediately mark the space as free; for example, on Windows it will wait until
## the last file handle to it is closed, and on UNIX, it will not remove it until the last
## [hard link](https://en.wikipedia.org/wiki/Hard_link) to it has been deleted.
##
## > [`File.delete`](File#delete) does the same thing, except it takes a [Str] instead of a [Path].
delete : Path -> Task {} [FileWriteErr Path WriteErr]
delete = \path ->
    pathBytes = InternalPath.toBytes path
    PlatformTasks.fileDelete pathBytes
    |> Task.mapErr \err -> FileWriteErr path (InternalFile.handleWriteErr err)

# read : Path, fmt -> Task contents [FileReadErr Path ReadErr, FileReadDecodingFailed] where contents implements Decoding, fmt implements DecoderFormatting
# read = \path, fmt ->
#    contents = readBytes! path

#    Decode.fromBytes contents fmt
#    |> Result.mapErr \_ -> FileReadDecodingFailed
#    |> Task.fromResult

# read = \path, fmt ->
#     effect = Effect.map (Effect.fileReadBytes (InternalPath.toBytes path)) \result ->
#         when result is
#             Ok bytes ->
#                 when Decode.fromBytes bytes fmt is
#                     Ok val -> Ok val
#                     Err decodingErr -> Err (FileReadDecodeErr decodingErr)
#             Err readErr -> Err (FileReadErr readErr)
#     InternalTask.fromEffect effect

## Reads a [Str] from a file containing [UTF-8](https://en.wikipedia.org/wiki/UTF-8)-encoded text.
##
## ```
## # Reads UTF-8 encoded text into a Str from the file "myfile.txt"
## Path.readUtf8 (Path.fromStr "myfile.txt")
## ```
##
## This opens the file first and closes it after writing to it.
## The task will fail with `FileReadUtf8Err` if the given file contains invalid UTF-8.
##
## > To read unformatted bytes from a file, you can use [Path.readBytes] instead.
## >
## > [`File.readUtf8`](File#readUtf8) does the same thing, except it takes a [Str] instead of a [Path].
readUtf8 : Path -> Task Str [FileReadErr Path ReadErr, FileReadUtf8Err Path _]
readUtf8 = \path ->
    bytes =
        PlatformTasks.fileReadBytes (InternalPath.toBytes path)
        |> Task.mapErr! \readErr -> FileReadErr path (InternalFile.handleReadErr readErr)

    Str.fromUtf8 bytes
    |> Result.mapErr \err -> FileReadUtf8Err path err
    |> Task.fromResult

## Reads all the bytes in a file.
##
## ```
## # Read all the bytes in `myfile.txt`.
## Path.readBytes (Path.fromStr "myfile.txt")
## ```
##
## This opens the file first and closes it after reading its contents.
##
## > To read and decode data from a file, you can use `Path.read` instead.
## >
## > [`File.readBytes`](File#readBytes) does the same thing, except it takes a [Str] instead of a [Path].
readBytes : Path -> Task (List U8) [FileReadErr Path ReadErr]
readBytes = \path ->
    pathBytes = InternalPath.toBytes path
    PlatformTasks.fileReadBytes pathBytes
    |> Task.mapErr \err -> FileReadErr path (InternalFile.handleReadErr err)

## Lists the files and directories inside the directory.
##
## > [`Dir.list`](Dir#list) does the same thing, except it takes a [Str] instead of a [Path].
listDir : Path -> Task (List Path) [DirErr DirErr]
listDir = \path ->
    result =
        InternalPath.toBytes path
        |> PlatformTasks.dirList
        |> Task.result!

    when result is
        Ok entries -> Task.ok (List.map entries InternalPath.fromOsBytes)
        Err err -> Task.err (handleErr err)

## Deletes a directory if it's empty
##
## This may fail if:
##   - the path doesn't exist
##   - the path is not a directory
##   - the directory is not empty
##   - the user lacks permission to remove the directory.
##
## > [`Dir.deleteEmpty`](Dir#deleteEmpty) does the same thing, except it takes a [Str] instead of a [Path].
deleteEmpty : Path -> Task {} [DirErr DirErr]
deleteEmpty = \path ->
    InternalPath.toBytes path
    |> PlatformTasks.dirDeleteEmpty
    |> Task.mapErr handleErr

## Recursively deletes a directory as well as all files and directories
## inside it.
##
## This may fail if:
##   - the path doesn't exist
##   - the path is not a directory
##   - the directory is not empty
##   - the user lacks permission to remove the directory.
##
## > [`Dir.deleteAll`](Dir#deleteAll) does the same thing, except it takes a [Str] instead of a [Path].
deleteAll : Path -> Task {} [DirErr DirErr]
deleteAll = \path ->
    InternalPath.toBytes path
    |> PlatformTasks.dirDeleteAll
    |> Task.mapErr handleErr

## Creates a directory
##
## This may fail if:
##   - a parent directory does not exist
##   - the user lacks permission to create a directory there
##   - the path already exists.
##
## > [`Dir.create`](Dir#create) does the same thing, except it takes a [Str] instead of a [Path].
createDir : Path -> Task {} [DirErr DirErr]
createDir = \path ->
    InternalPath.toBytes path
    |> PlatformTasks.dirCreate
    |> Task.mapErr handleErr

## Creates a directory recursively adding any missing parent directories.
##
## This may fail if:
##   - the user lacks permission to create a directory there
##   - the path already exists
##
## > [`Dir.createAll`](Dir#createAll) does the same thing, except it takes a [Str] instead of a [Path].
createAll : Path -> Task {} [DirErr DirErr]
createAll = \path ->
    InternalPath.toBytes path
    |> PlatformTasks.dirCreateAll
    |> Task.mapErr handleErr

# There are othe errors which may be useful, however they are currently unstable
# features see https://github.com/rust-lang/rust/issues/86442
# TODO add these when available
# ErrorKind::NotADirectory => RocStr::from("ErrorKind::NotADirectory"),
# ErrorKind::IsADirectory => RocStr::from("ErrorKind::IsADirectory"),
# ErrorKind::DirectoryNotEmpty => RocStr::from("ErrorKind::DirectoryNotEmpty"),
# ErrorKind::ReadOnlyFilesystem => RocStr::from("ErrorKind::ReadOnlyFilesystem"),
# ErrorKind::FilesystemLoop => RocStr::from("ErrorKind::FilesystemLoop"),
# ErrorKind::FilesystemQuotaExceeded => RocStr::from("ErrorKind::FilesystemQuotaExceeded"),
# ErrorKind::StorageFull => RocStr::from("ErrorKind::StorageFull"),
# ErrorKind::InvalidFilename => RocStr::from("ErrorKind::InvalidFilename"),
handleErr = \err ->
    when err is
        e if e == "ErrorKind::NotFound" -> DirErr NotFound
        e if e == "ErrorKind::PermissionDenied" -> DirErr PermissionDenied
        e if e == "ErrorKind::AlreadyExists" -> DirErr AlreadyExists
        e if e == "ErrorKind::NotADirectory" -> DirErr NotADirectory
        str -> DirErr (Other str)
