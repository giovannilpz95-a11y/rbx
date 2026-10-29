//! Minimal Luau host for running Crop Pop's shared modules and tests outside Roblox.
//!
//! Usage: luaurun <script.luau> [args...]
//!
//! Adds a few globals on top of the standard Luau library:
//!   readfile(path) -> string
//!   listdir(path) -> { { name: string, dir: boolean } }   (sorted by name)
//!   loadmodule(source, chunkname, env) -> function        (compiles with `env` as globals)
//!   compile(source, chunkname) -> (boolean, string?)      (syntax check only)
//!   clock() -> number                                     (seconds, monotonic)
//!   exit(code)
//!   ARGS -> { string }

use mlua::{Function, Lua, Result, Table, Value};
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: luaurun <script.luau> [args...]");
        std::process::exit(2);
    }
    if let Err(err) = run(&args[1], &args[2..]) {
        eprintln!("{err}");
        std::process::exit(1);
    }
}

fn run(path: &str, rest: &[String]) -> Result<()> {
    let lua = Lua::new();
    let globals = lua.globals();
    let started = Instant::now();

    globals.set(
        "readfile",
        lua.create_function(|_, path: String| {
            std::fs::read_to_string(&path).map_err(|e| mlua::Error::runtime(format!("{path}: {e}")))
        })?,
    )?;

    globals.set(
        "listdir",
        lua.create_function(|lua, path: String| {
            let mut entries: Vec<(String, bool)> = std::fs::read_dir(&path)
                .map_err(|e| mlua::Error::runtime(format!("{path}: {e}")))?
                .filter_map(|entry| entry.ok())
                .map(|entry| {
                    let dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
                    (entry.file_name().to_string_lossy().into_owned(), dir)
                })
                .collect();
            entries.sort();
            let out = lua.create_table()?;
            for (i, (name, dir)) in entries.into_iter().enumerate() {
                let row = lua.create_table()?;
                row.set("name", name)?;
                row.set("dir", dir)?;
                out.set(i + 1, row)?;
            }
            Ok(out)
        })?,
    )?;

    globals.set(
        "loadmodule",
        lua.create_function(|lua, (source, name, env): (String, String, Table)| {
            lua.load(source).set_name(format!("@{name}")).set_environment(env).into_function()
        })?,
    )?;

    globals.set(
        "compile",
        lua.create_function(|lua, (source, name): (String, String)| {
            match lua.load(source).set_name(format!("@{name}")).into_function() {
                Ok(_) => Ok((true, Value::Nil)),
                Err(e) => Ok((false, Value::String(lua.create_string(e.to_string())?))),
            }
        })?,
    )?;

    globals.set(
        "clock",
        lua.create_function(move |_, ()| Ok(started.elapsed().as_secs_f64()))?,
    )?;

    globals.set(
        "exit",
        lua.create_function(|_, code: i32| -> Result<()> { std::process::exit(code) })?,
    )?;

    let argv = lua.create_table()?;
    for (i, a) in rest.iter().enumerate() {
        argv.set(i + 1, a.as_str())?;
    }
    globals.set("ARGS", argv)?;

    let source = std::fs::read_to_string(path)
        .map_err(|e| mlua::Error::runtime(format!("{path}: {e}")))?;
    let main: Function = lua.load(source).set_name(format!("@{path}")).into_function()?;
    main.call::<()>(())
}
