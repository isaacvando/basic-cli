hosted PlatformTask
    exposes [
        args,
        dirList,
        dirCreate,
        dirCreateAll,
        dirDeleteEmpty,
        dirDeleteAll,
        envDict,
        envVar,
        cwd,
        setCwd,
        exePath,
        stdoutLine,
        stdoutWrite,
        stderrLine,
        stderrWrite,
        stdinLine,
        stdinBytes,
        ttyModeCanonical,
        ttyModeRaw,
        sendRequest,
        fileReadBytes,
        fileDelete,
        fileWriteUtf8,
        fileWriteBytes,
        fileReader,
        fileReadLine,
        closeFile,
        pathType,
        posixTime,
        tcpConnect,
        tcpClose,
        tcpReadUpTo,
        tcpReadExactly,
        tcpReadUntil,
        tcpWrite,
        sleepMillis,
        commandStatus,
        commandOutput,
        currentArchOS,
    ]
    imports [
        InternalHttp.{ Request, InternalResponse },
        InternalCommand,
        InternalPath,
    ]

stdoutLine : Str -> Task {} Str
stdoutWrite : Str -> Task {} Str
stderrLine : Str -> Task {} Str
stderrWrite : Str -> Task {} Str
stdinLine :  Task Str Str
stdinBytes : Task (List U8) {}
ttyModeCanonical : Task {} {}
ttyModeRaw : Task {} {}

fileWriteBytes : List U8, List U8 -> Task {} Str
fileWriteUtf8 : List U8, Str -> Task {} Str
fileDelete : List U8 -> Task {} Str
fileReadBytes : List U8 -> Task (List U8) Str

fileReader : List U8 -> Task U64 Str
fileReadLine : U64 -> Task (List U8) Str
closeFile : U64 -> Task {} {}

envDict : Task (Dict Str Str) {}
envVar : Str -> Task Str {}
exePath : Task (List U8) {}
setCwd : List U8 -> Task {} {}

# If we encounter a Unicode error in any of the args, it will be replaced with
# the Unicode replacement char where necessary.
args : Task (List Str) {}

cwd : Task (List U8) {}

sendRequest : Box Request -> Task InternalResponse {}

tcpConnect : Str, U16 -> Task U64 Str
tcpClose : U64 -> Task {} {}
tcpReadUpTo : U64, U64 -> Task (List U8) Str
tcpReadExactly : U64, U64 -> Task (List U8) Str
tcpReadUntil : U64, U8 -> Task (List U8) Str
tcpWrite : U64, List U8 -> Task {} Str

pathType : List U8 -> Task InternalPath.InternalPathType (List U8)

posixTime : Task U128 {}
sleepMillis : U64 -> Task {} {}

commandStatus : Box InternalCommand.Command -> Task {} (List U8)
commandOutput : Box InternalCommand.Command -> Task InternalCommand.Output {}

dirList : List U8 -> Task (List (List U8)) Str
dirCreate : List U8 -> Task {} Str
dirCreateAll : List U8 -> Task {} Str
dirDeleteEmpty : List U8 -> Task {} Str
dirDeleteAll : List U8 -> Task {} Str

currentArchOS : Task { arch : Str, os : Str } {}
