# rbx

## Connecting to the Matcha MCP server

This project can be used with the `matcha` MCP server over HTTP transport. To
connect Claude Code to a locally running instance:

1. Start the `matcha` MCP server so it is listening on `127.0.0.1:8765`.
2. Register it with Claude Code:

   ```sh
   claude mcp add --transport http --scope user matcha http://127.0.0.1:8765/mcp
   ```

   - `--transport http` connects over HTTP instead of stdio.
   - `--scope user` registers the server for your user account, making it
     available across all your Claude Code projects (not just this one).

3. Verify the connection:

   ```sh
   claude mcp list
   ```

   `matcha` should appear in the list with a healthy status.

To remove the server later, run:

```sh
claude mcp remove --scope user matcha
```
