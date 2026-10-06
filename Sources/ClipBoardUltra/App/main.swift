import Cocoa
import Darwin

setbuf(stdout, nil)
setbuf(stderr, nil)

let args = CommandLine.arguments

if args.contains(where: { $0.hasPrefix("--") }) {
    let cmd: String
    if args.contains("--show") { cmd = "show" }
    else if args.contains("--hide") { cmd = "hide" }
    else if args.contains("--shelf-clear") { cmd = "shelf-clear" }
    else if args.contains("--shelf-add") {
        if let idx = args.firstIndex(of: "--shelf-add"), idx + 1 < args.count {
            let path = args[idx + 1]
            cmd = "shelf-add \(path)"
        } else {
            cmd = "shelf"
        }
    }
    else if args.contains("--shelf") { cmd = "shelf" }
    else if args.contains("--settings-shelf") { cmd = "settings-shelf" }
    else if args.contains("--settings") { cmd = "settings" }
    else if args.contains("--about") { cmd = "about" }
    else { cmd = "toggle" }

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
