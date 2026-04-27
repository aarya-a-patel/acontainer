const std = @import("std");
const linux = std.os.linux;

pub fn main(init: std.process.Init) !void {
    try makeRootFs(init.io);

    const stack: [64 * 1024]u8 align(16) = undefined;
    const stack_top: usize = @intFromPtr(&stack) + stack.len;
    const flags = linux.CLONE.NEWNS |
        linux.CLONE.NEWPID |
        linux.CLONE.NEWIPC |
        linux.CLONE.NEWUTS |
        @intFromEnum(linux.SIG.CHLD);
    const pid = linux.clone2(flags, stack_top);
    if (linux.errno(pid) != .SUCCESS) return error.CloneFailed;

    if (pid == 0) {
        child();
    }

    var status: u32 = 0;
    const rc = linux.waitpid(@intCast(pid), &status, 0);
    if (linux.errno(rc) != .SUCCESS) return error.WaitPidFailed;

}

pub fn child() callconv(.c) void {
    if (linux.errno(linux.syscall2(.sethostname, @intFromPtr("acontainer"), "acontainer".len)) != .SUCCESS) {
        linux.exit(1);
    }
    if (linux.errno(linux.chroot("/tmp/rootfs")) != .SUCCESS) {
        linux.exit(1);
    }
    if (linux.errno(linux.chdir("/")) != .SUCCESS) {
        linux.exit(1);
    }
    _ = linux.mkdir("/proc", 0o755);
    if (linux.errno(linux.mount("proc", "/proc", "proc", 0, 0)) != .SUCCESS) {
        linux.exit(1);
    }

    const argv = [_:null]?[*:0]const u8{
        "/bin/sh",
        null,
    };
    const envp = [_:null]?[*:0]const u8{
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "TERM=xterm-256color",
        null,
    };
    _ = linux.execve("/bin/sh", &argv, &envp);
    linux.exit(1);
}

pub fn makeRootFs(io: std.Io) !void {
    try std.Io.Dir.createDirPath(.cwd(), io, "/tmp/rootfs");
    if (hasBootstrappedRootFs(io)) {
        return;
    }

    var debootstrap = try std.process.spawn(io, .{
        .argv = &.{
            "/bin/sh",                                                                       "-c",
            "debootstrap --variant=minbase stable /tmp/rootfs http://deb.debian.org/debian",
        },
        .expand_arg0 = .expand,
        .stdin = .ignore,
        .stdout = .inherit,
        .stderr = .inherit,
    });

    const term = try debootstrap.wait(io);
    switch (term) {
        .exited => |code| if (code != 0) return error.DebootstrapFailed,
        else => return error.DebootstrapFailed,
    }

    try std.Io.Dir.createDirPath(.cwd(), io, "/tmp/rootfs/proc");
}

fn hasBootstrappedRootFs(io: std.Io) bool {
    var file = std.Io.Dir.openFileAbsolute(io, "/tmp/rootfs/etc/debian_version", .{}) catch return false;
    defer file.close(io);
    return true;
}
