app [main] { pf: platform "../platform/main.roc" }

# pf.Stdout,
# pf.Stderr,
import pf.Task exposing [Task]
# pf.File,
# pf.Path,
# pf.Env,
# pf.Dir,

main =
    Task.ok {}

# TODO FIX
# path = "out.txt"
# task =
#     cwd <- Env.cwd |> Task.await
#     cwdStr = Path.display cwd

#     _ <- Stdout.line "cwd: $(cwdStr)" |> Task.await
#     dirEntries <- Dir.list cwd |> Task.await
#     contentsStr = Str.joinWith (List.map dirEntries Path.display) "\n    "

#     _ <- Stdout.line "Directory contents:\n    $(contentsStr)\n" |> Task.await
#     _ <- Stdout.line "Writing a string to out.txt" |> Task.await
#     _ <- File.writeUtf8 path "a string!" |> Task.await
#     contents <- File.readUtf8 path |> Task.await
#     Stdout.line "I read the file back. Its contents: \"$(contents)\""

# Task.attempt task \result ->
#     when result is
#         Ok {} -> Stdout.line "Successfully wrote a string to out.txt"
#         Err err ->
#             msg =
#                 when err is
#                     FileWriteErr _ PermissionDenied -> "PermissionDenied"
#                     FileWriteErr _ Unsupported -> "Unsupported"
#                     FileWriteErr _ (Unrecognized _ other) -> other
#                     FileReadErr _ _ -> "Error reading file"
#                     _ -> "Uh oh, there was an error!"

#             {} <- Stderr.line msg |> Task.await

#             Task.err 1 # 1 is an exit code to indicate failure
