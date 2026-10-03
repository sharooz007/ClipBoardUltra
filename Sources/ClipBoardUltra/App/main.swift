import Cocoa
import Darwin

setbuf(stdout, nil)
setbuf(stderr, nil)

let args = CommandLine.arguments

if args.contains("--show") || args.contains("--hide") || args.contains("--toggle") {
    let cmd = args.contains("--show") ? "show" : (args.contains("--hide") ? "hide" : "toggle")
    let path = "/tmp/clipboardultra.cmd"
    if let fh = FileHandle(forWritingAtPath: path) {
        fh.seekToEndOfFile()
        fh.write("\(cmd)\n".data(using: .utf8)!)
        try? fh.close()
    } else {
        try? "\(cmd)\n".write(toFile: path, atomically: false, encoding: .utf8)
    }
    print("[CLI] Dispatched '\(cmd)' command to running ClipBoardUltra.")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
