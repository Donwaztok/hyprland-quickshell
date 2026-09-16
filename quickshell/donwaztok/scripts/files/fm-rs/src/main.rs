//! Donwaztok file manager CLI — Rust port of fm.py.

mod compress;
mod entry;
mod extract;
mod list;
mod mounts;
mod ops;
mod protocol;
mod thumb;
mod trash;
mod watch;

use clap::{Parser, Subcommand};
use protocol::err_exit;

#[derive(Parser)]
#[command(name = "fm", about = "Donwaztok file manager helpers")]
struct Cli {
    #[command(subcommand)]
    cmd: Commands,
}

#[derive(Subcommand)]
enum Commands {
    List {
        path: String,
        #[arg(long)]
        hidden: bool,
    },
    Mounts,
    #[command(name = "xdg-dirs")]
    XdgDirs,
    #[command(name = "smart-extract")]
    SmartExtract {
        archive: String,
        #[arg(long)]
        dest: Option<String>,
    },
    /// Compress paths into a zip or 7z in dest
    #[command(name = "smart-compress")]
    SmartCompress {
        dest: String,
        sources: Vec<String>,
        #[arg(long, default_value = "zip")]
        format: String,
    },
    Mkdir {
        path: String,
    },
    Rename {
        src: String,
        dst: String,
    },
    Trash {
        paths: Vec<String>,
    },
    Restore {
        uris: Vec<String>,
    },
    #[command(name = "empty-trash")]
    EmptyTrash,
    Delete {
        paths: Vec<String>,
    },
    Copy {
        dest: String,
        sources: Vec<String>,
    },
    Move {
        dest: String,
        sources: Vec<String>,
    },
    #[command(name = "undo-move")]
    UndoMove {
        /// to from to from …
        pairs: Vec<String>,
    },
    Eject {
        mount: String,
    },
    Mount {
        device: String,
    },
    Open {
        paths: Vec<String>,
    },
    Thumb {
        path: String,
        dest: String,
        #[arg(long, default_value_t = 64)]
        size: i32,
    },
    Info {
        paths: Vec<String>,
    },
    Watch {
        path: String,
    },
}

fn main() {
    let cli = Cli::parse();
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| run(cli)));
    if let Err(e) = result {
        let msg = if let Some(s) = e.downcast_ref::<&str>() {
            (*s).to_string()
        } else if let Some(s) = e.downcast_ref::<String>() {
            s.clone()
        } else {
            "internal error".into()
        };
        err_exit(&msg);
    }
}

fn run(cli: Cli) {
    match cli.cmd {
        Commands::List { path, hidden } => list::list_dir(&path, hidden),
        Commands::Mounts => mounts::list_mounts(),
        Commands::XdgDirs => mounts::xdg_dirs(),
        Commands::SmartExtract { archive, dest } => {
            extract::smart_extract(&archive, dest.as_deref())
        }
        Commands::SmartCompress {
            dest,
            sources,
            format,
        } => {
            if sources.is_empty() {
                err_exit("smart-compress requires sources");
            }
            compress::smart_compress(&dest, &sources, &format)
        }
        Commands::Mkdir { path } => ops::do_mkdir(&path),
        Commands::Rename { src, dst } => ops::do_rename(&src, &dst),
        Commands::Trash { paths } => {
            if paths.is_empty() {
                err_exit("trash requires at least one path");
            }
            trash::do_trash(&paths)
        }
        Commands::Restore { uris } => {
            if uris.is_empty() {
                err_exit("restore requires at least one uri");
            }
            trash::do_restore(&uris)
        }
        Commands::EmptyTrash => trash::do_empty_trash(),
        Commands::Delete { paths } => {
            if paths.is_empty() {
                err_exit("delete requires at least one path");
            }
            ops::do_delete(&paths)
        }
        Commands::Copy { dest, sources } => {
            if sources.is_empty() {
                err_exit("copy requires sources");
            }
            ops::do_copy(&sources, &dest)
        }
        Commands::Move { dest, sources } => {
            if sources.is_empty() {
                err_exit("move requires sources");
            }
            ops::do_move(&sources, &dest)
        }
        Commands::UndoMove { pairs } => ops::do_undo_move(&pairs),
        Commands::Eject { mount } => mounts::do_eject(&mount),
        Commands::Mount { device } => mounts::do_mount(&device),
        Commands::Open { paths } => {
            if paths.is_empty() {
                err_exit("open requires at least one path");
            }
            ops::do_open_many(&paths)
        }
        Commands::Thumb { path, dest, size } => thumb::do_thumb(&path, &dest, size),
        Commands::Info { paths } => {
            if paths.is_empty() {
                err_exit("info requires at least one path");
            }
            ops::do_info(&paths)
        }
        Commands::Watch { path } => watch::watch_dir(&path),
    }
}
